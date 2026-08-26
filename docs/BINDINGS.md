# Bindings Reference

Complete reference of all keymaps, user commands, and autocommands defined by
Reposcope.

## Table of Contents

- [1. Keymaps](#1-keymaps)
  - [1.1 Global (user-configurable)](#11-global-user-configurable)
  - [1.2 Prompt buffers](#12-prompt-buffers)
  - [1.3 Close-UI (all Reposcope buffers)](#13-close-ui-all-reposcope-buffers)
  - [1.4 Component-local](#14-component-local)
- [2. User Commands](#2-user-commands)
- [3. Autocommands](#3-autocommands)

---

## 1. Keymaps

### 1.1 Global (user-configurable)

Defined in [`lua/reposcope/bindings/keymaps.lua`](../lua/reposcope/bindings/keymaps.lua)
(`set_user_keymaps`), sourced from `config.keymaps` /
`config.keymap_opts` (see [`lua/reposcope/config/init.lua`](../lua/reposcope/config/init.lua)).
Mode: `n` (normal). Set `keymaps.open`/`keymaps.close` to `false` or `""` to
disable that mapping entirely.

| Key            | Action           | Default option    |
| -------------- | ---------------- | ------------------ |
| `<leader>rs`   | Open Reposcope   | `keymaps.open`     |
| `<leader>rc`   | Close Reposcope  | `keymaps.close`    |

Both keys and `silent`/`noremap` options can be overridden via `setup({ keymaps = {...}, keymap_opts = {...} })`.

### 1.2 Prompt buffers

Defined in [`lua/reposcope/bindings/keymaps.lua`](../lua/reposcope/bindings/keymaps.lua)
(`set_prompt_keymaps`), sourced from `config.prompt_keymaps`. Applied
buffer-local to all prompt field buffers (`ui_state.buffers.prompt`). Each
action can be rebound to a different key (or a list of keys), or disabled by
setting it to `false`/`""` in `setup({ prompt_keymaps = {...} })`.

| Action                 | Default key(s)                | Mode   | Description                                          |
| ---------------------- | ------------------------------ | ------ | ------------------------------------------------------ |
| `confirm`              | `<CR>`                         | i      | Confirm prompt input (`prompt_input.on_enter`)          |
| `nav_up`               | `<Up>`                         | n, i   | Navigate list up + fetch README for selected entry. A count moves that many entries (normal mode) |
| `nav_down`             | `<Down>`                       | n, i   | Navigate list down + fetch README for selected entry. A count moves that many entries (normal mode) |

**A count on `nav_up`/`nav_down`** moves that many entries at once, clamped
to the list bounds. Handled inside `navigate_list_in_prompt` itself — one
call moves `v:count1` rows — so the README is fetched once, after the move,
rather than once per intermediate entry. `v:count` is 0 in insert mode, where
these keys are also bound, so the behaviour there is unchanged.
| `focus_next`           | `<C-w>`, `<C-l>`, `<Tab>`      | n, i   | Focus next prompt field                                 |
| `focus_prev`           | `<C-h>`, `<S-Tab>`             | n, i   | Focus previous prompt field                             |
| `open_viewer`          | `<C-v>`                        | n, i   | Open README viewer                                      |
| `open_editor`          | `<C-b>`                        | n, i   | Open README editor                                      |
| `clone`                | `<C-c>`                        | n, i   | Clone selected repository (prompt for target dir, with directory completion) |
| `backspace`            | `<BS>`                         | n, i   | Backspace (disabled at column 0, line 2 of prompt)       |
| `preview_scroll_up`    | `<C-u>`                        | n, i   | Scroll the README preview up, without leaving the prompt |
| `preview_scroll_down`  | `<C-d>`                        | n, i   | Scroll the README preview down, without leaving the prompt |
| `help`                 | `?`                            | n      | Show the `?` keymap cheatsheet (normal mode only, so `?` still types in insert mode) |
| `toggle_favorite`      | `<C-f>`                        | n, i   | Toggle favorite for the currently selected repository (see `:Reposcope favorites`) |

All prompt keymaps carry a `desc` so they are picked up automatically by
[which-key](https://github.com/folke/which-key.nvim) if it's installed — no
extra registration needed. `reposcope.bindings.keymaps.list_active_prompt_keymaps()`
is the single source of truth both the `?` cheatsheet (`ui/actions/help_view.lua`)
and this table are derived from.

### 1.3 Close-UI (all Reposcope buffers)

Defined in [`lua/reposcope/bindings/keymaps.lua`](../lua/reposcope/bindings/keymaps.lua)
(`set_close_ui_keymaps`). Applied to background, preview, list, and all
prompt buffers.

| Key      | Mode         | Action                       |
| -------- | ------------ | ---------------------------- |
| `<Esc>`  | n            | Close Reposcope UI            |
| `<Esc>`  | i, t, v      | Switch to normal mode         |
| `<C-w>`  | n            | Close Reposcope UI            |
| `<C-w>`  | i, t, v      | No-op (`<Nop>`, disabled)     |

### 1.4 Component-local

Not part of `set_ui_keymaps()` — each is set/unset by its own component
whenever it opens/closes.

| Key           | Mode | Where                                       | Action                                                    |
| ------------- | ---- | -------------------------------------------- | ---------------------------------------------------------- |
| `q`           | n    | [`ui/actions/readme_viewer.lua`](../lua/reposcope/ui/actions/readme_viewer.lua) (`nvim_buf_set_keymap`) | Closes the README viewer, restores prompt autocmds + prompt keymaps |
| `q`, `<Esc>`  | n    | [`utils/stats.lua`](../lua/reposcope/utils/stats.lua) | Closes the stats popup buffer/window                        |
| `q`, `<Esc>`  | n    | [`ui/actions/help_view.lua`](../lua/reposcope/ui/actions/help_view.lua) (via `lib.nvim.ui.kit`'s `nice_quit`) | Closes the `?` keymap cheatsheet |
| `<CR>`, `<2-LeftMouse>` | n | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, on every interactive `--out` backend of `:Reposcope status`) | Prompts to confirm (`lib.nvim.ui.kit`'s button-confirm dialog), then opens the `README.md` of the repository under the cursor (`:edit`). A repository with no readable `README.md` just gets a notification — nothing to confirm |
| `p`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Pushes the repository under the cursor (`utils/repo_actions.lua`), then re-reads and redraws that row |
| `P`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Pulls the repository under the cursor (`git pull --ff-only`), then re-reads and redraws that row |
| `f`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Fetches the repository under the cursor (`git fetch --prune`), then re-reads and redraws that row |
| `S`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Opens a nested popup with the repository's `git status --short` and its last five commits |
| `s`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Cycles the sort order: discovery → name → state (worst first) → last-commit age → discovery |
| `r`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Re-reads the repository under the cursor and redraws that row |
| `R`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Re-scans every repository in the directory the overview was built from |
| `y`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Yanks the path of the repository under the cursor into `+` and `"` |
| `?`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, same backends as above) | Lists every status-overview key, generated from the same table that installs them |
| `q`           | n    | [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua) (`lib.nvim.bindings.keymap`, buffer-local on a README opened from a status row) | Wipes the README buffer and restores the status overview on the same row |

The status-overview keys above are declared in one table in
[`status_view.lua`](../lua/reposcope/ui/actions/status_view.lua), which also
generates the `winbar` legend and the `?` cheatsheet, so the three can't drift
apart. `r`, `R` and `y` are intentionally left out of the legend to keep it on
one line; `?` lists them.

---

## 2. User Commands

Defined in [`lua/reposcope/bindings/usrcmds.lua`](../lua/reposcope/bindings/usrcmds.lua)
as subcommands of the single dispatcher `:Reposcope <subcommand> [args]`.
Running `:Reposcope` with no arguments prints this list. Tab-completion is
available for subcommand names and, where noted, their arguments.

| Subcommand         | Args                  | Description                                                           |
| ------------------- | --------------------- | ---------------------------------------------------------------------- |
| `start`             | –                      | Open the Reposcope UI                                                  |
| `close`             | –                      | Close all Reposcope windows and buffers                                |
| `prompt`            | `[field ...]`          | Reload visible prompt fields (default: `keywords owner language`)      |
| `sort`              | –                      | Open an interactive menu to sort the repository list                   |
| `filter`            | `[text]`               | Filter the repository list by substring (no args resets the list). Completes against the names and owners actually on screen |
| `filter-prompt`     | –                      | Open a floating prompt to filter repositories interactively            |
| `filter-clear`      | –                      | Clear the active filter and show the full list again                   |
| `update`            | `[dir]`                | Update (fetch + ff-only pull) all cloned repositories in a directory   |
| `status`            | `[dir] [--out] [--to]` | Show the git status overview of repositories in a directory (see below) |
| `providers`         | –                      | List available providers and mark the active one                      |
| `session`           | `save`\|`restore`\|`clear` | Save, restore, or clear the persisted search session (provider, prompt input, query, filter, sort) |
| `favorites`         | `list`\|`clear`        | List favorited repositories in a popup, or clear all favorites        |
| `queries`           | `list`\|`clear`        | Print your top-10 most-frequent search queries, or clear the stats    |
| `stats`             | –                      | Display collected request stats and metrics                           |
| `skipped-readmes`   | –                      | Print the number of debounced (skipped) README fetches                |
| `toggle-dev`        | –                      | Toggle developer mode (debug logging, internal info)                  |
| `print-dev`         | –                      | Print whether developer mode is currently active                      |

`status`'s `--out` selects the output backend (`popup` default, `buffer`,
`split`, `vsplit`, `clipboard`, `path`), and `--to=<file>` sets the target
file for `--out=path`. `<Tab>` on `[dir]` offers `$REPOS_DIR` and `~` ahead of
real directory completion (see `fixed_dir_keywords` in
[`bindings/usrcmds.lua`](../lua/reposcope/bindings/usrcmds.lua)). See
[`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua)
and [COMMANDS.md](COMMANDS.md#reposcope-status-dir---out---to) for details.

`favorites`/`queries` are backed by
[`state/favorites_state.lua`](../lua/reposcope/state/favorites_state.lua) and
[`state/query_stats.lua`](../lua/reposcope/state/query_stats.lua) — both
single-JSON-file persistence under the plugin's cache directory, following
the same conventions as `state/session_state.lua`. A favorite snapshots the
repository's metadata plus its README content (if already cached) at the
moment it's toggled, so viewing it later needs no live re-fetch. Query stats
are recorded automatically on every real search (`prompt_input.on_enter`) —
no opt-in needed, since it's local-only and never leaves the cache directory.

---

## 3. Autocommands

### Global

Defined in [`lua/reposcope/bindings/autocmds.lua`](../lua/reposcope/bindings/autocmds.lua),
registered via `reposcope.init`'s `setup_ui_close`.

| Event     | Pattern                | Group | Action                                                        |
| --------- | ----------------------- | ----- | ---------------------------------------------------------------- |
| `QuitPre` | (checked in callback)  | –     | If the closed window's buffer name matches `reposcope://*`, closes the whole UI |

### Prompt

Defined in [`lua/reposcope/ui/prompt/prompt_autocmds.lua`](../lua/reposcope/ui/prompt/prompt_autocmds.lua),
group `reposcope_prompt_autocmds` (cleared/recreated on setup, removed on `cleanup_autocmds`).

| Event(s)                                                    | Action                                                             |
| ------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `TextChangedI`                                                | Reads line 2 of the active prompt buffer, stores it as that field's text |
| `CursorMoved`, `CursorMovedI`, `InsertEnter`, `InsertLeave`   | Locks the cursor to line 2 of the current prompt buffer                  |
