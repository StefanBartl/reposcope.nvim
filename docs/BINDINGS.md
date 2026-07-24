# Bindings Reference

Complete reference of all keymaps, user commands, and autocommands defined by
Reposcope.

## Table of Contents

- [1. Keymaps](#1-keymaps)
  - [1.1 Global (user-configurable)](#11-global-user-configurable)
  - [1.2 Prompt buffers](#12-prompt-buffers)
  - [1.3 Close-UI (all Reposcope buffers)](#13-close-ui-all-reposcope-buffers)
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

| Action        | Default key(s)                | Mode   | Description                                          |
| ------------- | ------------------------------ | ------ | ------------------------------------------------------ |
| `confirm`     | `<CR>`                         | i      | Confirm prompt input (`prompt_input.on_enter`)          |
| `nav_up`      | `<Up>`                         | n, i   | Navigate list up + fetch README for selected entry      |
| `nav_down`    | `<Down>`                       | n, i   | Navigate list down + fetch README for selected entry    |
| `focus_next`  | `<C-w>`, `<C-l>`, `<Tab>`      | n, i   | Focus next prompt field                                 |
| `focus_prev`  | `<C-h>`, `<S-Tab>`             | n, i   | Focus previous prompt field                             |
| `open_viewer` | `<C-v>`                        | n, i   | Open README viewer                                      |
| `open_editor` | `<C-b>`                        | n, i   | Open README editor                                      |
| `clone`       | `<C-c>`                        | n, i   | Clone selected repository (prompt for target dir)       |
| `backspace`   | `<BS>`                         | n, i   | Backspace (disabled at column 0, line 2 of prompt)       |

All prompt keymaps carry a `desc` so they are picked up automatically by
[which-key](https://github.com/folke/which-key.nvim) if it's installed — no
extra registration needed.

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
| `filter`            | `[text]`               | Filter the repository list by substring (no args resets the list)      |
| `filter-prompt`     | –                      | Open a floating prompt to filter repositories interactively            |
| `filter-clear`      | –                      | Clear the active filter and show the full list again                   |
| `update`            | `[dir]`                | Update (fetch + ff-only pull) all cloned repositories in a directory   |
| `status`            | `[dir] [--out] [--to]` | Show the git status overview of repositories in a directory (see below) |
| `providers`         | –                      | List available providers and mark the active one                      |
| `stats`             | –                      | Display collected request stats and metrics                           |
| `skipped-readmes`   | –                      | Print the number of debounced (skipped) README fetches                |
| `toggle-dev`        | –                      | Toggle developer mode (debug logging, internal info)                  |
| `print-dev`         | –                      | Print whether developer mode is currently active                      |

`status`'s `--out` selects the output backend (`popup` default, `buffer`,
`split`, `vsplit`, `clipboard`, `path`), and `--to=<file>` sets the target
file for `--out=path`. See [`ui/actions/status_view.lua`](../lua/reposcope/ui/actions/status_view.lua)
and [COMMANDS.md](COMMANDS.md#reposcope-status-dir---out---to) for details.

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
