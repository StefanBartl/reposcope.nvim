# Features

Finding a plugin, reading its README and cloning it is three context switches
out of the editor. This one covers all three.

| Area | Does |
| --- | --- |
| **Search** | Across GitHub, GitLab and Codeberg, in a modular Telescope-inspired interface, with the selected repository's README rendered in the preview as you move |
| **Clone** | Straight from the result list into your clone directory |
| **The cache** | READMEs are cached and precached, which is what makes moving through results feel instant and what the hover integration reads from |
| **Narrowing** | Filter and sort the current results, save favorites with an offline README snapshot, and track your most-frequent queries |
| **Sessions** | The last search, filter and sort mode restored across restarts |

A catalog of Reposcope's shipped features, grouped by theme. It is the
source of truth for *what* shipped: every entry names the feature, what it
does, and the module, config key, command or keymap behind it — so a
feature can be traced from its description to its code without a search.

For how those features combine into a day-to-day routine rather than a
list, see [`docs/WORKFLOW.md`](../WORKFLOW.md).

## Files

- **[PROVIDERS.md](PROVIDERS.md)** — GitHub/GitLab/Codeberg search and README
  fetching, cloning, and provider selection.
- **[UI.md](UI.md)** — the list/prompt/preview UI, keymaps, colors,
  filtering and sorting, the start view, and the help cheatsheet.
- **[CACHE.md](CACHE.md)** — README caching (RAM + file), staleness
  detection, pre-warming, pre-caching, debouncing, and what the request
  log records.
- **[WORKFLOW.md](WORKFLOW.md)** — everything reached through
  `:Reposcope <subcommand>`: sessions, favorites, query history, and
  diagnostics/metrics.
