# UI

The list/prompt/preview/background windows, their keymaps, colors, and the
help system built on top of them.

## Full UI (list, prompt, preview, background) in dynamic layout

Four coordinated floating windows — repository list, input prompt, README
preview, and a background layer — laid out and resized together, opened by
a single command and torn down together on close.

- **Module:** `ui/list/list_window.lua`, `ui/prompt/*`,
  `ui/preview/preview_window.lua`, `ui/background/background_window.lua`,
  `controllers/repository_ui_loader.lua`
- **Config:** `layout` (default `"default"`)
- **Usercmds:** `:Reposcope start` / `:Reposcope close` (see
  [COMMANDS.md](../COMMANDS.md))

## Viewer/editor for README content

`<C-v>` opens the currently previewed README fullscreen for reading (or in
the system browser if the content looks like HTML); `<C-b>` instead drops
it into a hidden, named scratch buffer for scripting/exporting.

- **Module:** `ui/actions/readme_viewer.lua` (`M.open_viewer`),
  `ui/actions/readme_editor.lua` (`M.open_editor`)
- **Keymaps:** `<C-v>` (viewer), `<C-b>` (editor) — see
  [BINDINGS.md](../BINDINGS.md#keymaps)

## Help docs via `:h reposcope`

Full `:help`-integrated documentation shipped as a real Vim help file.

- **Module:** `doc/reposcope.txt`
- **Usercmds:** `:h reposcope`

## `?` keymap cheatsheet, generated from the same table that drives the actual bindings

Pressing `?` shows a popup listing every active prompt keymap and its
action, built from the exact same `ACTION_ORDER`/keymap table
`bindings/keymaps.lua` uses to bind the keys — so the cheatsheet can never
drift out of sync with what is actually bound.

- **Module:** `ui/actions/help_view.lua` (`M.show`), `bindings/keymaps.lua`
  (`ACTION_ORDER`)
- **Keymaps:** `?` (normal mode only) — see
  [BINDINGS.md](../BINDINGS.md#keymaps)

## Scroll the README preview (`<C-u>`/`<C-d>`) without leaving the prompt

Scrolls the preview window up/down while keeping keyboard focus in the
prompt, so browsing a long README needs no window switch.

- **Module:** `ui/prompt/prompt_manager.lua`, `ui/preview/preview_manager.lua`
- **Config:** `prompt_keymaps.preview_scroll_up`/`preview_scroll_down`
  (default `<C-u>`/`<C-d>`)

## List/preview highlight colors sourced from the active colortheme

List selection/text colors and preview highlighting read from the active
colortheme instead of fixed hex values, so a colorscheme switch via
`ui.config.update_theme()` is reflected without any Reposcope-specific
configuration.

- **Module:** `ui/config.lua` (`colortheme`, `update_theme`),
  `ui/list/list_config.lua`, `ui/preview/preview_config.lua`

## Configurable `prefix` field symbol (`prompt_prefix_symbol`)

The icon shown in the prompt's `prefix` field is a plain config string, so
a Nerd Font glyph can be swapped for `"> "` or anything else on terminals
without icon font support.

- **Config:** `prompt_prefix_symbol` (default a Nerd Font icon)

## Favorite repositories with persisted metadata + README snapshot (`<C-f>`, `:Reposcope favorites`)

Toggling a favorite snapshots the repository's metadata (owner, name,
description, URL, stars) and its README content (if already cached), so
viewing a favorite later needs no live re-fetch. Persisted as JSON under
the plugin's cache directory.

- **Module:** `state/favorites_state.lua`, `ui/actions/favorites_view.lua`
- **Keymaps:** `<C-f>` (toggle) — see
  [BINDINGS.md](../BINDINGS.md#keymaps)
- **Usercmds:** `:Reposcope favorites list|clear` (see
  [COMMANDS.md](../COMMANDS.md))

## Start view — show favorites immediately on open instead of an empty prompt

`:Reposcope start` populates the repository list from persisted favorites
right away when any exist, feeding them through the same
`repository_cache`/`list_controller` path a real search result would use —
list navigation, preview, sorting and filtering all work identically on
this start view.

- **Module:** `controllers/start_view_controller.lua`
  (`M.show_favorites_if_any`)
- **Config:** none — automatic whenever favorites exist.
