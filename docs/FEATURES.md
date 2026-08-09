# Features

- 🔍 Dynamic repository search by topic, owner, language, etc. — GitHub, GitLab and Codeberg supported (`provider` option)
- 📄 Live preview of `README.md` with inline Markdown rendering
- 🧠 Persistent README caching (RAM + file system)
- 🔧 Clone support: `git`, `gh`, `wget`, `curl`
- 🔄 Bulk-update all cloned repositories (`git fetch` + ff-only `pull`) in one command
- 📋 Git status overview across a whole folder of repos (branch, ahead/behind, dirty)
- 🔁 Debounced README fetches to avoid redundant API calls
- 📦 Clean, fully modular architecture (UI, state, providers, controllers)
- 🧪 Strongly annotated with EmmyLua for LuaLS support
- 📊 Built-in request metrics and logging (optional toggle)
- 📑 README viewer (`<C-v>`) or README editor buffer (`<C-b>`)
- ⌨️ Keymaps for navigation, cloning, and UI control
- 📁 Customizable prompt fields (e.g. `prefix`, `keywords`, `owner`, ...)
- 💾 Persistent session save/restore — last search, filter and sort mode (`:Reposcope session save|restore|clear`)
- ❓ `?` keymap cheatsheet — floating overlay listing every active keymap, generated from the same table that drives the actual bindings (never drifts)
- 📜 Scroll the README preview (`<C-u>`/`<C-d>`) without leaving the prompt
- 🎨 List/preview highlight colors now derive from the active colortheme instead of separate hardcoded hex values, so `ui.config.update_theme()` actually reaches them
- 🔤 Customizable `prefix` field symbol (`prompt_prefix_symbol`) for terminals without a Nerd Font
- ⭐ Favorite repositories (`<C-f>` to toggle, `:Reposcope favorites`) — persists metadata *and* the README content (if cached), so viewing a favorite later needs no re-fetch
- 📈 Query-frequency tracking (`:Reposcope queries`) — every real search is counted, top-10 most-frequent printed on demand
- 🏁 Start view — opening Reposcope with favorites already saved shows them immediately (list + preview pre-warmed from the favorite's own README snapshot, no network call), instead of an empty prompt

---

## Features Demo

https://github.com/user-attachments/assets/85dece1d-d755-4de9-9cd1-84a751901fc2
