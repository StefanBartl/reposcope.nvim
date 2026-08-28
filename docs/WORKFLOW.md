# Workflow — getting real use out of reposcope.nvim day to day

Every feature here is documented on its own elsewhere (`docs/FEATURES/*.md`,
`docs/COMMANDS.md`, `docs/AUTHENTICATION.md`). This is the different
question: once search, README caching, cloning, bulk maintenance and session
persistence all exist at once, *how do they actually combine* into something
worth reaching for daily, rather than a one-off "find a repo, clone it,
forget the plugin exists" tool.

For the repo-maintenance/session/diagnostics *command* catalog specifically,
see [`docs/FEATURES/WORKFLOW.md`](FEATURES/WORKFLOW.md) — this file is the
broader picture of how a session actually flows.

## The core loop: search → preview → clone

The everyday shape is `:Reposcope start` → type into prompt fields → `<CR>`
to search → arrow through the list → read the live-rendered README in the
preview window → `<C-c>` to clone. Each step feeds the next without leaving
the floating UI:

- Prompt fields (`keywords`, `owner`, `language`, `topic`, `stars`, `prefix`)
  build a real provider query string (`providers/*/query_builder.lua`), not
  a free-text box — so narrowing a search means editing one field
  (`<Tab>`/`<S-Tab>` to cycle) and re-running, not retyping everything.
- Moving the list selection (`<Up>`/`<Down>`) fetches that repository's
  README into the preview window automatically, through the RAM/file cache
  first (see below) — only a cache miss hits the network.
- `<C-c>` clones the currently selected repository into `clone.std_dir`
  using whatever `clone.type` is configured (`git` by default, or
  `gh`/`curl`/`wget`), via `controllers/clone_executor.lua`.

That "discover → clone" pair is also where the maintenance commands pick up:
`:Reposcope status`/`:Reposcope update` treat `clone.std_dir` as their own
default target, so a directory you only ever populate via `<C-c>` is the
same directory those commands sweep later. Point `clone.std_dir` at one
place and the whole loop — search, clone, update, status — stays coherent
without ever passing an explicit path.

## Debounce and background pre-caching change what "instant" means

Two mechanisms quietly shape how the list-scrolling part of the loop feels,
and they matter for expectations, not just performance:

- **Debounced README fetches**: moving quickly through the list does not
  fire a fetch per row — only the row you settle on. `:Reposcope
  skipped-readmes` reports how many fetches were skipped this way, which is
  a genuinely useful sanity check if a README seems to be missing new
  content after fast scrolling (it usually means the fetch was skipped, not
  that the cache is stale).
- **Background pre-caching** (`readme_precache_count`, default `5`): right
  after a search completes, the top N results' READMEs are fetched in the
  background regardless of whether you ever scroll to them. Combined with
  debouncing, this means the first few rows of any search feel instant even
  on a fresh session, while rows further down still pay a real fetch on
  first visit. Set `readme_precache_count = 0` to disable this if you're on
  a metered connection or want to minimize API calls.

## When a cached README goes stale, and how to force a refresh

READMEs are cached in two layers (RAM, then file — `cache/readme_cache.lua`)
and trusted by default: a repeat visit to a repository you've already
opened this session, or across a restart, serves the cached copy instead of
re-fetching.

Staleness detection (`has_fresh`) only kicks in when the provider supplies
an `updated_at`/`last_activity_at` value for the repository: the value
recorded at cache time is compared against the current one, and a mismatch
forces a re-fetch. When a provider doesn't supply that field, the cache is
trusted indefinitely — there's nothing to compare against, so a repository
could change upstream without reposcope ever noticing.

Practical consequence: if a README looks out of date and staleness
detection isn't catching it (or you just want to guarantee a live copy),
there's no per-repository "refresh" command — the reset is at the cache
layer:

- `cache.readme_cache.clear(owner, repo_name)` (Lua, `both`/`ram`/`file`
  target) for a single repository.
- `cache.readme_cache.clear_all()` to wipe everything (RAM + file +
  freshness metadata) and start over.

There is currently no `:Reposcope` subcommand wrapping either — both are
Lua API calls, worth knowing if you script your own keymap for "force
refresh this repo."

## Bulk update and status are a pair, not two separate features

`:Reposcope status` and `:Reposcope update` operate on the same directory
(`clone.std_dir` by default, or a given path) and the same repository
discovery (`utils/repos.lua`, immediate subdirectories only, non-recursive).
Treat `status` as the read-only preview of what `update` is about to do:

1. `:Reposcope status` — shows branch, sync state, working-tree state
   (`clean`/`dirty`/`ahead`/`behind`/`diverged`) and the age of `HEAD` per
   repo, read via `git status --porcelain=v2 --branch`. Nothing is modified by
   the scan itself; the row and batch keys in the overview are what modify,
   and each batch asks first (see *Marks turn the row keys into batch keys*).
   `gu` in that overview is `update` applied to the same directory, so in
   practice step 2 is usually one keystroke away rather than a second
   command. The `SYNC` column carries arrows (`↑2 ↓1`) only for
   branches that have actually diverged, and disappears entirely when no
   repository has anything to report there — which is the normal case, and the
   reason a `+0/-0` on every row used to bury the two that mattered.
2. `:Reposcope update [dir]` — runs `git fetch --all --prune` then `git pull
   --ff-only` per repo, sequentially, asynchronously. A repo already shown
   as `diverged` in `status` will fail (not rewrite) in `update` — the
   fast-forward-only pull refuses to rewrite local history, so `diverged`
   repos need manual attention regardless of how many times `update` runs.

Both scan **only immediate subdirectories** of the target — nested clones
(a repo inside a repo) are invisible to either command. If you organize
clones into per-provider or per-org subfolders under `clone.std_dir`, point
`status`/`update` at the specific subfolder rather than the root, or they'll
report "no repositories found."

`status --out=path` is worth knowing for anything beyond eyeballing the
popup: it writes the raw table to a file instead, which is the natural
input to a shell script if you want "list every dirty repo" outside Neovim
entirely.

## The status overview is a dashboard, not a printout

Every row is actionable, and that is the difference between checking on
thirty clones and maintaining them.

`p` pushes, `P` pulls (`--ff-only`), `f` fetches (`--prune`) the repository
under the cursor. After each one the row is re-read and redrawn in place, so
the table stays true without a rescan. `r` re-reads one row, `R` re-scans the
whole directory — and `:Reposcope status <dir>` passes that directory through,
so `R` re-reads what you actually asked for rather than the configured default.

## Marks turn the row keys into batch keys

The interesting unit of maintenance is rarely one repository and rarely all
of them: it is *these six*. So `m` marks the row under the cursor (`Vjjm`
marks a run of them), and while anything is marked `p`, `P` and `f` act on
the marked set instead of on the cursor row. Same keys, same meaning, one
scale up — which is why there is no second alphabet of uppercase batch verbs
to learn, and why unmarking everything silently gives you the old
single-row behaviour back.

`gp`, `gP`, `gf` and `gu` are the whole-directory forms, marks ignored:
push all, pull all, fetch all, update all. `gu` is `:Reposcope update`
without leaving the dashboard — the same `fetch --all --prune` +
`pull --ff-only`, run through the same code path — so the loop closes where
you are already looking: scan, see what is behind, update it, watch the rows
go clean.

Three deliberate constraints:

- **Batches confirm; single rows do not.** A row action names its target by
  the line the cursor is on. A batch may touch repositories scrolled off
  screen, so the count is the only thing that can state what is about to
  happen — and it has to be stated before, not after.
- **Batches are sequential.** Forty parallel `git push`es are a rate limit,
  forty credential prompts, or both. Cancelling through the progress
  indicator stops the queue from starting the next repository rather than
  interrupting the `git` call in flight — a half-done fetch is harmless, an
  interrupted `pull` is not.
- **Marks belong to repositories, not rows.** They are stored by path, so
  `s` (re-sort), `R` (re-scan) and closing/reopening the overview all leave
  them where you put them. The reverse — `s` or `R` *during* a batch — is
  refused outright, since both would slide rows out from under the
  in-flight spinners.

`S` opens a nested popup with the full `git status --short` and the last five
commits: the natural next step when a row says `dirty` and you want to know
whether that is a stray build artifact or real work.

`s` cycles the sort order — discovery / name / state / age. **`state` ranks
worst-first** (diverged, dirty, behind, ahead, clean) rather than
alphabetically, so what needs attention floats up; that is the one to reach for
on a directory you have not looked at in a while. Discovery order is kept as a
snapshot, so the cycle is reversible without a rescan.

`y` yanks the repository path, which is how you leave the dashboard for a
terminal. `?` lists every binding, generated from the same table that installs
them. The winbar legend deliberately shows only some of them — `r`, `R` and `y`
are left out so it does not overflow, and `?` is where the full list lives.

**Opening a README from a row is reversible now.** It used to tear the popup
down with no way back short of re-running the whole directory scan; the README
buffer now carries a buffer-local `q` that wipes it and restores the overview
on the same row.

## Session persistence restores search state, not window layout

`:Reposcope session save`/`restore`/`clear` (`state/session_state.lua`)
persists exactly: the active provider, the visible prompt fields, what was
typed into each, the last built search query, the active filter text, and
the sort mode — as one JSON file that overwrites on every `save`.

What it does **not** touch:

- **Window layout.** The `layout` config option and the UI's floating
  window arrangement are unrelated to session state — `restore` re-opens
  results into whatever layout is currently configured, not whatever was
  active when you saved.
- **README cache contents.** Restoring a session re-runs the last search
  live; whether each result's README comes from cache or a fresh fetch is
  governed by the cache/staleness rules above, independently of session
  save/restore.
- **Anything automatically.** Nothing is saved on close or on a timer —
  `session save` is a deliberate action. If you close Neovim without
  running it, the next `:Reposcope start` opens exactly as if no session
  ever existed (or shows favorites, see below).

`restore` re-runs the search asynchronously and only re-applies the saved
filter/sort *after* results come back — so scripting `session restore`
immediately followed by another command that assumes the list is already
populated will race it.

## Favorites are the persistence layer that *does* survive without a save

Where sessions require an explicit `save`, favorites (`<C-f>`,
`state/favorites_state.lua`) persist the moment you toggle one — metadata
(owner, name, description, URL, stars) and the README content if it was
already cached, so a favorite is self-contained and needs no live re-fetch
to view later.

This is what makes `:Reposcope start` behave differently depending on
history: with any favorites saved, the repository list is pre-populated
from them immediately (`controllers/start_view_controller.lua`) — no prompt,
no network call, first entry's preview already warm. Without favorites, you
get the plain empty prompt. In other words, favorites function as a
lightweight, always-on alternative to session save/restore for the
repositories you actually care to keep coming back to, while sessions cover
the exact *search* you were mid-way through.

## Provider switching resets more than the search results

`provider` (`github`/`gitlab`/`codeberg`) determines which query grammar,
README fetch path, and clone path are used — but switching providers via
config does not migrate the prompt/session/cache state between them.
Consequences worth knowing before assuming continuity across a switch:

- A saved session records the provider it was saved under
  (`data.provider`); restoring it switches `config.options.provider` back
  to whatever was active at save time — so `session restore` can silently
  flip your active provider if you've since changed it.
- README/favorite caches are keyed by `owner/repo_name` only, not by
  provider — a GitHub and a Codeberg repo that happen to share
  `owner/repo_name` would collide in the cache. Unlikely in practice, but
  not impossible if you mirror repos across providers under the same path.
- `:Reposcope providers` is the cheap way to confirm which provider is
  actually active before trusting that a search or clone went where you
  expected — useful right after a `session restore` for exactly the reason
  above.

## Token setup affects which clone tool is safe to use, not just rate limits

Per [`docs/AUTHENTICATION.md`](AUTHENTICATION.md), reposcope works
unauthenticated by default (`curl`/`wget`-based requests, no clone tool
requiring auth) but at GitHub's lower anonymous rate limit. Two details
that matter once you reach for `gh` as the clone/request tool specifically:

- A `gh auth login` session is **not** visible to reposcope's child
  processes — `gh`-based requests silently fail without an explicit
  `github_token` passed into `setup()` (or `GITHUB_TOKEN` in the
  environment, forwarded explicitly, since Neovim doesn't always inherit
  shell env vars depending on how it was launched).
- `gitlab_token`/`codeberg_token` are the equivalent knobs for the other
  two providers — set the one matching whichever `provider` you actually
  use, not all three.

If searches or clones start failing after a provider switch, the token for
the *newly active* provider — not the one you were using before — is the
first thing worth checking.

## Diagnostics as a loop-debugging tool, not just a toggle

`:Reposcope toggle-dev` plus `:Reposcope stats`/`:Reposcope skipped-readmes`
are most useful together when something in the loop above feels off:
`stats` shows accumulated request/cache metrics (`utils/metrics.lua`) so you
can tell whether a slow preview is a cache miss or a genuinely slow
network call, and `skipped-readmes` distinguishes "debounce skipped this
fetch on purpose" from "something is actually broken." Both are read-only
and safe to check mid-session without disrupting the current search.

## `:Reposcope filter` completes against what is on screen

The filter is a substring over `owner/name: description`, so the only
candidates that can match anything are the repository names and owners in the
current result set — and those are what it completes, prefix-matched. Owners
are offered alongside names because narrowing to one owner is a real thing to
want.

Guessing at a filter and getting an empty list back was the whole friction, and
it is the reason to reach for `<Tab>` here rather than typing.

## Cross-references

- [`docs/FEATURES/PROVIDERS.md`](FEATURES/PROVIDERS.md) — per-provider
  search/README/clone mechanics.
- [`docs/FEATURES/CACHE.md`](FEATURES/CACHE.md) — cache internals,
  staleness detection, pre-warming/pre-caching.
- [`docs/FEATURES/UI.md`](FEATURES/UI.md) — the floating windows, keymaps,
  viewer/editor, help cheatsheet.
- [`docs/FEATURES/WORKFLOW.md`](FEATURES/WORKFLOW.md) — the
  `update`/`status`/`session`/`queries`/diagnostics command catalog this
  file assumes you've already skimmed.
- [`docs/COMMANDS.md`](COMMANDS.md) — full command reference with syntax
  and examples.
- [`docs/AUTHENTICATION.md`](AUTHENTICATION.md) — token setup per provider.
