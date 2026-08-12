# Cache

README caching: what is stored, where, how it is kept fresh, and how it is
warmed ahead of time so browsing feels instant.

## File-based README cache

Every fetched README is written to disk under the plugin's cache
directory, in addition to an in-memory (RAM) copy, so content survives
Neovim restarts without a re-fetch.

- **Module:** `cache/readme_cache.lua` (`M.get`, `M.has`, `M.set_ram`,
  `M.set_file`, `M.get_file`, `M.clear`, `M.clear_all`)
- **Config:** cache directory resolved via `config.get_readme_filecache_dir()`

## README staleness detection, RAM pre-warming, and background pre-caching

Three related mechanisms around the README cache:

- **Staleness detection** (`has_fresh`) compares a repository's
  `updated_at`/`last_activity_at` against the value recorded when its
  README was cached, treating the cache as a miss when the repo changed
  since.
- **RAM pre-warming** (`warm_ram_from_file_cache`) loads every file-cached
  README into RAM once at startup, so the first navigation to an
  already-cached repo in a fresh session is not a disk read.
- **Background pre-caching** fetches READMEs for the top N search results
  right after a search completes, so scrolling into them feels instant.

- **Module:** `cache/readme_cache.lua` (`M.has_fresh`, `M.set_updated_at`,
  `M.get_cached_updated_at`, `M.warm_ram_from_file_cache`),
  `controllers/provider_controller.lua`
- **Config:** `readme_precache_count` (default `5`, `0` disables
  pre-caching)

## Metrics/logging correctness fixes

A set of correctness fixes to the request/cache logging pipeline: clone
operations are now logged, request/cache-hit log entries carry a real
`url` field, a bug where a repository's own URL was logged into the
cache-hit "source" field instead of `"ram"`/`"file"` was fixed, and
`check_rate_limit()`'s dead reference to a nonexistent module was
corrected.

- **Module:** `utils/metrics.lua`, `@types/classes/utils.lua`
