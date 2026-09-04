# Workflow

Repository maintenance, session persistence, and diagnostics — everything
reached through `:Reposcope <subcommand>` that isn't search/browse itself.

> **Not to be confused with [`docs/WORKFLOW.md`](../WORKFLOW.md).** This
> file is one theme of the feature catalog: a per-feature entry naming the
> module, config key and command behind each of these subcommands. The
> top-level `docs/WORKFLOW.md` is the other question entirely — how search,
> caching, cloning, maintenance and sessions *combine* into a routine worth
> reaching for daily. Catalog here, narrative there.

## Bulk-update all cloned repositories (`:Reposcope update`)

Runs `git fetch --all --prune` followed by `git pull --ff-only` for every
immediate subdirectory of a directory (default: `clone.std_dir`),
sequentially and asynchronously so Neovim stays responsive. Diverged
branches are reported as errors rather than rewritten.

- **Module:** `utils/repo_updater.lua` (`M.update_all`),
  `bindings/usrcmds.lua` (`run_update`)
- **Config:** `clone.std_dir`
- **Usercmds:** `:Reposcope update [dir]` (see
  [commands.md](../commands.md#reposcope-update-dir))

## Git status overview of cloned repositories (`:Reposcope status`)

Reads `git status --porcelain=v2 --branch` for every repo directly inside
a directory (or a single repo) and shows branch, ahead/behind counts, and
dirty state (`clean`/`dirty`/`ahead`/`behind`/`diverged`) in a compact
table. The scan is the read-only counterpart to `update`; the rows are not
— `m` marks repositories and `p`/`P`/`f` then act on the marked set, while
`gp`/`gP`/`gf`/`gu` act on every repository in the overview.

- **Module:** `utils/repo_status.lua` (`M.status_all`, `M.status_one`),
  `utils/repo_actions.lua` (per-repo push/pull/fetch/update),
  `ui/actions/status_view.lua`, `bindings/usrcmds.lua` (`run_status`,
  `status_route`)
- **Config:** `clone.std_dir`, `progress_style`
- **Usercmds:** `:Reposcope status [dir] [--out] [--to]` (see
  [commands.md](../commands.md#reposcope-status-dir---out---to))

## Persistent session save/restore (last search, filters, sort)

Persists the active provider, visible prompt fields and their typed-in
text, the last built search query, the active filter text, and the
current sort mode to a single JSON file under the plugin's cache
directory, surviving Neovim restarts. Nothing is saved automatically —
the command below decides when a session is worth keeping.

- **Module:** `state/session_state.lua` (`M.save`, `M.restore`, `M.clear`)

## `:Reposcope session save|restore|clear` – manage persisted sessions

The command surface for the session mechanism above: `save` writes the
current session (overwriting any previous one), `restore` brings back the
saved provider/prompt/input and re-runs the last search (re-applying the
saved filter and sort once results arrive), `clear` deletes the saved
session file.

- **Module:** `bindings/usrcmds.lua` (`subcommands.session`)
- **Usercmds:** `:Reposcope session save|restore|clear` (see
  [commands.md](../commands.md#reposcope-session-saverestoreclear))

## Query-frequency tracking (`:Reposcope queries`)

Every real search increments a persisted run-count for the exact query
built, with no opt-in needed — recorded locally only. `queries list`
prints the top 10, most-frequent first.

- **Module:** `state/query_stats.lua` (`M.top`, `M.clear_all`)
- **Usercmds:** `:Reposcope queries list|clear` (see
  [commands.md](../commands.md#reposcope-queries-listclear))

## Metrics, logging, and developer diagnostics

Session-level request/cache metrics (`utils/metrics.lua`) plus a
developer-mode toggle that enables debug logging and internal info
printing.

- **Module:** `utils/metrics.lua`, `utils/debug.lua`, `utils/stats.lua`
  (`M.show_stats`)
- **Config:** `metrics` (default `false`), `log_max` (default `1000`)
- **Usercmds:** `:Reposcope toggle-dev`, `:Reposcope print-dev`,
  `:Reposcope stats`, `:Reposcope skipped-readmes` (see
  [commands.md](../commands.md#debugging-stats--metrics))
