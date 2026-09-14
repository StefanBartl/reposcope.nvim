# TESTS/

Headless spec suite. Nothing here touches the network, a picker or a window —
every spec drives a module directly and asserts on what it returns.

```
nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
```

Exit 0 is a pass; the runner prints one line per spec and exits non-zero on the
first failure. CI runs exactly this command.

## lib.nvim and ui.nvim

Several modules require lib.nvim at module load, and `status_view.lua`
(exercised directly by `status_view_spec.lua`) requires `ui.kit` the same
way, so the suite cannot run without either. `run.lua` resolves each in
this order:

1. `$LIB_NVIM_PATH` / `$UI_NVIM_PATH`
2. a sibling checkout, `../lib.nvim` / `../ui.nvim`
3. the lazy.nvim-managed copy under `stdpath("data")/lazy/lib.nvim` /
   `stdpath("data")/lazy/ui.nvim`

A sibling wins over the plugin-manager copy on purpose: that one is often older
than the working checkout, and testing against a stale lib.nvim/ui.nvim gives
misleading failures.

## The specs

| | |
| --- | --- |
| `core_utils_spec.lua` | the small pure helpers, including `ensure_string`'s handling of `vim.NIL` — what decoded JSON nulls arrive as |
| `query_builder_spec.lua` | prompt input to each forge's search syntax, and that a malformed input is an empty query rather than a crash |
| `repository_cache_spec.lua` | what a decoded API response turns into, what the list buffer shows, and the fields the API omits |
| `config_spec.lua` | the merge — including that `setup()` here accumulates rather than rebuilding from DEFAULTS, unlike the sibling plugins |
| `status_view_spec.lua` | the status overview's rendering (column offsets, highlights) and that marks add a gutter without shifting the rest of the row |
| `preview_image_spec.lua` | `find_url`, the pure half of the README image preview: badge blocks are skipped and the first real raster URL is picked |
| `hover_spec.lua` | the hover.nvim contribution — the `owner/repo` slug test, and that the source answers only for repositories reposcope has cached |
| `readme_urls_spec.lua` | the three providers' README URL builders (raw host vs. API endpoint) |
| `list_window_spec.lua` | `list_window`'s viewport handling: `reveal_line` scrolls a selection below the fold into view |

Adding one: write `TESTS/<name>_spec.lua` returning `function(H) ... end`, then
list it in `run.lua`. `H` is the harness — `eq`, `ok`, `falsy`, `contains`,
`excludes`, `read` and `fixture`.
