# Troubleshooting & Debugging

## Common symptoms

| Symptom | Where to look |
| --- | --- |
| The preview stays empty | The repository has no README at the expected path, or the API request failed. `:Reposcope stats` shows whether the fetch was attempted |
| `gh`-backed requests fail silently | A `gh auth login` session is not visible to Neovim's child processes. Set `github_token` explicitly — see [`authentication.md`](authentication.md) |
| A README looks out of date after fast scrolling | The fetch was debounced, not the cache stale. `:Reposcope skipped-readmes` prints the count |
| `:Reposcope status`/`update` report "no repositories found" | Both scan only *immediate* subdirectories. Point them at the folder that directly contains the clones |
| A repository never leaves `diverged` | `pull --ff-only` refuses to rewrite local history. That one needs manual attention |
| Something is missing from the environment | `:checkhealth reposcope` — see [health.md](health.md) for what each line means |

## Developer mode

- `:Reposcope toggle-dev` enables debug logging and internal info printing;
  `:Reposcope print-dev` reports whether it is currently on.
- `require("reposcope.utils.debug").notify(...)` is the entry point for
  developer output from your own code.
- `metrics = true` in `setup()` enables request timing and logging.
- `:Reposcope stats` displays the collected request/cache metrics for the
  session.

## Where the files are

Everything Reposcope writes lives under `stdpath("cache")/reposcope` — run
`:echo stdpath("cache") .. "/reposcope"` to see the absolute path on your
system (it differs between Linux, macOS and Windows).

| Path (relative to `stdpath("cache")/reposcope`) | Contents |
| --- | --- |
| `data/readme/` | The file-based README cache |
| `data/readme_meta.json` | README freshness metadata (`updated_at` per cached repository) |
| `data/session.json` | The session persisted by `:Reposcope session save` |
| `data/favorites.json` | The favorites list, including each favorite's README snapshot |
| `data/query_stats.json` | The per-query run counts behind `:Reposcope queries` |
| `logs/request_log.json` | The request log, written when `metrics = true` |

The request log holds one entry per `uuid:type` — `api_success`,
`api_failed`, `cache_hit`, `filecache_hit` — and each entry carries the
`query`, the `source` (the tool or cache layer that answered: `"curl"`,
`"gh"`, `"clone"`, `"ram"`, `"file"`), the `context`, and, where one
exists, the actual request or repository `url` in its own field. `log_max`
caps its size.

## Forcing a fresh README

There is no per-repository refresh command. The reset is at the cache
layer, in Lua:

```lua
-- One repository (target: "both" | "ram" | "file")
require("reposcope.cache.readme_cache").clear("owner", "repo", "both")

-- Everything: RAM, file cache, and the freshness metadata
require("reposcope.cache.readme_cache").clear_all()
```

Worth knowing if you want to bind your own "force refresh this repository"
key. In the normal case staleness detection handles this on its own — see
[`configuration.md`](configuration.md#readme-caching).
