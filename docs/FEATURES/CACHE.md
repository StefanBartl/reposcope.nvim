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

## Debounced README fetches

Moving quickly through the repository list does not fire one fetch per
row — only the row the selection settles on. `:Reposcope skipped-readmes`
reports how many fetches were skipped this way, which is the first thing
to check when a README looks like it is missing content after fast
scrolling: the fetch was skipped, not the cache stale.

- **Module:** `controllers/provider_controller.lua`,
  `ui/list/list_manager.lua`
- **Usercmds:** `:Reposcope skipped-readmes` (see
  [commands.md](../commands.md#debugging-stats--metrics))

## What the request and cache log records

Every request and every cache hit is written to the request log
(`metrics = true`) as one entry per `uuid:type` — `api_success`,
`api_failed`, `cache_hit`, `filecache_hit`. An entry carries the `query`,
the `source` (the tool or cache layer that answered: `"curl"`, `"gh"`,
`"clone"`, `"ram"`, `"file"`), the `context`, and, where one exists, the
actual request or repository `url` in its own field. Clone operations are
logged through the same path.

- **Module:** `utils/metrics.lua`, `@types/classes/utils.lua`
- **Config:** `metrics` (default `false`), `log_max` (default `1000`)
- **Docs:** [`docs/troubleshooting.md`](../troubleshooting.md) for the log
  file's location
