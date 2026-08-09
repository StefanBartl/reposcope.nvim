# Roadmap

Record of shipped features. For everything currently implemented, see
[BINDINGS.md](BINDINGS.md). There is no open backlog at the moment — new
planned items are added here as they come up.

## 1. Shipped

- [x] GitHub repository search (field-based)
- [x] GitHub README rendering (raw + API fallback)
- [x] Clone repo with tool of choice (`git`, `gh`, `curl`, `wget`)
- [x] Bulk-update all cloned repositories (`:Reposcope update`)
- [x] Git status overview of cloned repositories (`:Reposcope status`)
- [x] File-based README cache
- [x] Full UI (list, prompt, preview, background) in dynamic layout
- [x] Metrics, logging, and developer diagnostics
- [x] Viewer/editor for README content
- [x] Help docs via `:h reposcope`
- [x] GitLab provider support
- [x] Codeberg provider support
- [x] `:Reposcope providers` – list available/active providers
- [x] Persistent session save/restore (last search, filters, sort)
- [x] `:Reposcope session save|restore|clear` – manage persisted sessions
- [x] `?` keymap cheatsheet, generated from the same table that drives the actual bindings
- [x] Scroll the README preview (`<C-u>`/`<C-d>`) without leaving the prompt
- [x] List/preview highlight colors sourced from the active colortheme
- [x] Configurable `prefix` field symbol (`prompt_prefix_symbol`)
- [x] Favorite repositories with persisted metadata + README snapshot (`<C-f>`, `:Reposcope favorites`)
- [x] Query-frequency tracking (`:Reposcope queries`)
- [x] Start view — show favorites immediately on open instead of an empty prompt
- [x] README staleness detection (`updated_at`/`last_activity_at` comparison), RAM pre-warming from file cache, and background pre-caching of top search results (`readme_precache_count`)
