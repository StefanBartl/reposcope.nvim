# Development & Debugging

* Use `:Reposcope prompt prefix topic` to dynamically reload prompt fields
* Use `require("reposcope.utils.debug").notify(...)` for developer output
* Toggle metrics in config: `metrics = true`
* Debug file paths and logs are stored in:
  * `~/.local/share/nvim/reposcope/data/readme/`
  * `~/.local/share/nvim/reposcope/logs/request_log.json` — one entry per
    `uuid:type` (`api_success`, `api_failed`, `cache_hit`, `filecache_hit`);
    each entry carries `query`, `source` (tool/cache-source, e.g. `"curl"`,
    `"gh"`, `"clone"`, `"ram"`, `"file"`), `context`, and (where available)
    a dedicated `url` field with the actual request/repository URL
  * `~/.local/share/nvim/reposcope/data/session.json` — persisted `:Reposcope session save` state
  * `~/.local/share/nvim/reposcope/data/favorites.json` — persisted `:Reposcope favorites` list
  * `~/.local/share/nvim/reposcope/data/query_stats.json` — persisted `:Reposcope queries` counts
  * `~/.local/share/nvim/reposcope/data/readme_meta.json` — README freshness metadata (`updated_at` per cached repo)
