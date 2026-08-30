# Features

- 🔍 Dynamic repository search by topic, owner, language, etc. — GitHub, GitLab and Codeberg supported (`provider` option)
- 📄 Live preview of `README.md` with inline Markdown rendering
- 🧠 Persistent README caching (RAM + file system)
- 🔧 Clone support: `git`, `gh`, `wget`, `curl`
- 🔄 Bulk-update all cloned repositories (`git fetch` + ff-only `pull`) in one command
- 📋 Interactive git status dashboard across a whole folder of repos (branch, sync, state, last-commit age, colored by state) — `<CR>` opens a row's README.md (`q` returns to the dashboard), `p`/`P`/`f` push/pull/fetch it in place with live progress, `S` shows its full `git status`, `s` cycles the sort order, `r`/`R` refresh, `y` yanks the path, `?` lists every key
- ✅ Marks and batches in that dashboard — `m` marks a row (or a Visual selection), after which `p`/`P`/`f` act on the whole marked set; `gp`/`gP`/`gf`/`gu` push, pull, fetch or update *every* repo in the folder. Batches confirm first, run sequentially through the progress indicator, and refresh each row as it lands
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
- 🔄 README staleness detection — a cached README is re-fetched only if the repository actually changed since (`updated_at`/`last_activity_at`), instead of trusting the cache forever
- 🔥 RAM cache pre-warmed from the file cache on `setup()` — no disk-read penalty on the first visit to an already-cached repo in a fresh session
- ⏩ Background pre-caching of the top N search results' READMEs (`readme_precache_count`) so scrolling feels instant
- 🖼️ README image in the preview (`<C-p>`, needs [images.nvim](https://github.com/StefanBartl/images.nvim)) — draws the repository's screenshot or demo GIF over the preview pane. A keypress rather than automatic, and measured: 8 of 25 repositories carry a real image, the ones that do cost ~900ms, and finding out that a repository has none costs nothing because the check runs against the already-cached README
- 🩹 Clone operations, cache hits, and request logging now correctly record the actual URL and cache source (RAM/file) instead of a URL mistakenly landing in the "source" field

---

## Features Demo

https://github.com/user-attachments/assets/85dece1d-d755-4de9-9cd1-84a751901fc2
