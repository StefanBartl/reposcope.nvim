# Features

A `docs/FEATURES_FORMAT.md`-shaped catalog of Reposcope's shipped features,
grouped by theme. Source of truth for *what shipped* stays
[`docs/ROADMAP.md`](../ROADMAP.md) ("Shipped" section); this folder exists
so `documentation.nvim`'s Features tab (and any human reading this repo) has
a per-feature summary with the module, config key, and command behind it.

## Files

- **[PROVIDERS.md](PROVIDERS.md)** — GitHub/GitLab/Codeberg search and README
  fetching, cloning, and provider selection.
- **[UI.md](UI.md)** — the list/prompt/preview UI, keymaps, colors, the
  start view, and the help cheatsheet.
- **[CACHE.md](CACHE.md)** — README caching (RAM + file), staleness
  detection, pre-warming and pre-caching.
- **[WORKFLOW.md](WORKFLOW.md)** — everything reached through
  `:Reposcope <subcommand>`: repo maintenance (`update`/`status`),
  sessions, favorites, query history, and diagnostics/metrics.
