# Workflow — getting real use out of reposcope.nvim day to day

Every feature here is documented on its own elsewhere (`docs/FEATURES/*.md`,
`docs/commands.md`, `docs/authentication.md`). This is the different
question: once search, README caching, cloning and session persistence all
exist at once, *how do they actually combine* into something worth reaching
for daily, rather than a one-off "find a repo, clone it, forget the plugin
exists" tool.

> Multi-repo git maintenance (a status dashboard, bulk fetch/pull/update
> across a whole folder of clones) used to live here too, as `:Reposcope
> dashboard`/`:Reposcope update`. It moved to gitsuite.nvim's `:Git
> dashboard`/`:Git dashboard update` — git tooling belongs there, not in a
> repository-discovery plugin.

> **There is a second file called `WORKFLOW.md`, and it is not this one.**
> [`docs/FEATURES/WORKFLOW.md`](FEATURES/WORKFLOW.md) is one theme of the
> feature catalog: the per-feature entries for the maintenance, session,
> favorites, query-history and diagnostics subcommands, each naming its
> module and config key. This file is the narrative — how those pieces plus
> search, caching and cloning combine into a routine. Catalog there,
> narrative here.

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

`cache.readme_cache.clear(owner, repo_name, target)` drops one repository,
`clear_all()` wipes everything including the freshness metadata. There is no
`:Reposcope` subcommand wrapping either — both are Lua API calls, worth
knowing if you script your own "force refresh this repo" keymap. The exact
snippets are in
[`docs/troubleshooting.md`](troubleshooting.md#forcing-a-fresh-readme).

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

Per [`docs/authentication.md`](authentication.md), reposcope works
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
  `session`/`queries`/diagnostics command catalog this file assumes you've
  already skimmed.
- [`docs/commands.md`](commands.md) — full command reference with syntax
  and examples.
- [`docs/authentication.md`](authentication.md) — token setup per provider.
- [`docs/troubleshooting.md`](troubleshooting.md) — symptoms, developer
  mode, and where the cache and log files live.
