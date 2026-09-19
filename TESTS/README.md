# TESTS/

Headless spec suite. Nothing here touches the network, spawns a process, or
needs a picker backend — every spec drives a module directly and asserts on
what it returns, on the request it *would* have made, or on the lines it would
have rendered.

```
nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
```

Exit 0 is a pass; the runner prints one line per spec and exits non-zero after
reporting every spec that failed. CI runs exactly this command.

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

## No network, no processes

The rule is absolute, and it is enforced by cutting each seam *before* the
module under test is required. Every module in this plugin binds its
dependencies to file-local upvalues at load time
(`local x = require("...").x`), so patching a field on an already-loaded module
is too late — the subject is still holding the original function. `H.with_stubs`
exists for exactly this: it replaces modules in `package.loaded`, unloads the
subject so the next `require` rebuilds it against the doubles, and afterwards
restores `package.loaded` to a whole-table snapshot so nothing leaks into a
later spec.

| Seam | Replaced in | Covers |
| --- | --- | --- |
| `lib.nvim.cross.uv.spawn_capture` | `request_tools_spec` | the only place `curl`/`gh`/`wget` reach the OS |
| `reposcope.network.request_tools.{gh,curl,wget}` | `http_client_spec` | tool selection and the auth header |
| `reposcope.network.clients.http_client` | `http_client_spec` | `api_client`'s `Accept` header and result flattening |
| `reposcope.network.clients.api_client` | `repository_fetcher_spec`, `readme_fetcher_spec`, `metrics_spec` | every search, README and rate-limit request |
| `reposcope.providers.*.readme.readme_fetcher` | `readme_manager_spec` | the managers' cache/freshness gating |
| `reposcope.providers.*.repositories.repository_fetcher` | `repository_manager_spec` | the managers' UUID gating |
| `reposcope.controllers.clone_executor` | `clone_spec` | the clone argv, without cloning |
| `lib.nvim.cross.run_argv` | `protection_spec` | both shell entry points |
| `vim.system` | `repos_util_spec` | every `git` call in `repo_actions`/`repo_status` |
| `vim.fn.system` | `protection_spec` | the string form of `safe_execute_shell` |
| `vim.ui.input` | `provider_controller_spec` | the clone-path prompt |
| `vim.health` | `health_spec` | `:checkhealth reposcope` |
| `ui.kit` | `actions_spec` | the three read-only floats, at their content boundary |

`init_spec.lua` is the one deliberate exception to "no real UI": it opens and
closes the actual Reposcope windows. Neovim builds floating windows perfectly
well headless, and a lifecycle test whose only evidence is "the double was
called" would not catch a window that fails to close.

Anything that writes to disk (README cache, favorites, session, query stats,
the request log) is redirected into a fixture directory under `TESTS/` first.
The user's real `stdpath("cache")` is never touched.

## The specs

Run order (see `run.lua`) goes smallest layer first, so a failure points at the
lowest thing that broke.

### Leaf utilities

| | |
| --- | --- |
| `core_utils_spec.lua` | the small pure helpers, including `ensure_string`'s handling of `vim.NIL` — what decoded JSON nulls arrive as |
| `utils_spec.lua` | `error` (the `Result` shape, and the argument-hole caveat in `safe_call`), `env`, `checks`' request-tool resolver, `os`, `debug`'s notification gate, and `progress` both with and without lib.nvim |
| `encoding_text_spec.lua` | URL encoding of the qualifier syntax, base64 round trips, and the line shaping (`center_text`, `cut_text_for_line`, `gen_padded_lines`) every window uses |
| `protection_spec.lua` | filename/path validation, `safe_mkdir`, the named-buffer registry, both debounce wrappers, and both shell entry points |

### Configuration and state

| | |
| --- | --- |
| `config_spec.lua` | the merge — `setup()` rebuilds from DEFAULTS on every call, so `setup({})` resets |
| `config_options_spec.lua` | `get_option`'s four computed answers (`request_tool`, `clone`, `logfile_path`, `cache_dir`) and the derived cache paths |
| `state_spec.lua` | the request registry's two-phase gate, the prompt's per-field text, and `ui_state`'s handles/invocation/reset surface |
| `session_state_spec.lua` | `:Reposcope session save\|restore\|clear` end to end, including a corrupt and a wrongly-typed session file |
| `query_stats_spec.lua` | the persisted search-frequency counters and their stable ranking |
| `favorites_state_spec.lua` | persisted favorites: load/toggle, and that a corrupt favorites.json is backed up rather than silently discarded |

### Caches

| | |
| --- | --- |
| `repository_cache_spec.lua` | what a decoded API response turns into, what the list buffer shows, and the fields the API omits |
| `repository_cache_selection_spec.lua` | resolving the selection out of the real list buffer, and the relevance snapshot behind `:Reposcope sort relevance` |
| `readme_cache_spec.lua` | RAM/disk tiering, the path sanitiser (a name off the network cannot escape the cache directory), the freshness sidecar, clearing, and the startup warm-up |

### Network stack

| | |
| --- | --- |
| `request_tools_spec.lua` | the argv `curl`/`gh`/`wget` would have run, the credential that must not appear in it, the 20s timeout, and the success/exit-code/timeout/metrics fan-out |
| `http_client_spec.lua` | tool selection incl. the `gh`→`curl` fallback for non-GitHub hosts, the per-provider auth header, and `api_client`'s `Accept` header |

### Provider layer

| | |
| --- | --- |
| `query_builder_spec.lua` | prompt input to each forge's search syntax, and that a malformed input is an empty query rather than a crash |
| `readme_urls_spec.lua` | the three providers' README URL builders (raw host vs. API endpoint) |
| `repository_fetcher_spec.lua` | all three search fetchers: the URL, and every response branch (transport error, undecodable body, wrong shape, empty result set, success incl. normalization) |
| `readme_fetcher_spec.lua` | all three README fetchers: both routes, the base64 decode, and each refusal |
| `readme_manager_spec.lua` | all three README managers as one contract (UUID gating, freshness short-circuit, raw→API fallback, the "user navigated away" race), plus GitHub's private-repository shortcut |
| `repository_manager_spec.lua` | all three search managers' gating and failure handling, and the shape of every provider entrypoint |
| `clone_spec.lua` | the three argv builders, the three clone managers, `clone_info` and the executor |

### Controllers

| | |
| --- | --- |
| `controllers_spec.lua` | the list renderer, the post-search UI loader incl. the README pre-cache window, and the favourites start view |
| `provider_controller_spec.lua` | the dispatcher: the registry, the unknown-provider path, debounced README fetches with their skip counter, and the clone prompt |

### Metrics and repository maintenance

| | |
| --- | --- |
| `metrics_spec.lua` | the session counters, the bounded JSON request log, the totals read back from it, the rate-limit probe, and `utils.stats`' aggregations |
| `repos_util_spec.lua` | discovery (`.git` directory *and* file), the single-repository git actions, the update queue, and the status reader/parser incl. every derived state |

### Wiring, health and the UI-facing actions

| | |
| --- | --- |
| `bindings_spec.lua` | every `:Reposcope` subcommand through a real `:` call, two-level completion through real `getcompletion()`, the keymap layer against real buffers, and the QuitPre autocmd |
| `health_spec.lua` | `:checkhealth reposcope` against a recorded `vim.health`, with the installed tools/token/images.nvim/prompt fields all scripted — so the result does not depend on the machine running the suite |
| `actions_spec.lua` | filtering, sorting, the prompt's collect/search path, `prompt_reload`, and the content of the favourites/help/filter floats |
| `readme_views_spec.lua` | the README editor and viewer: cache fallbacks, the HTML-goes-to-the-browser decision, the real viewer window and its `q` keymap |
| `status_view_spec.lua` | the status overview's rendering (column offsets, highlights) and that marks add a gutter without shifting the rest of the row |
| `preview_image_spec.lua` | `find_url`, the pure half of the README image preview: badge blocks are skipped and the first real raster URL is picked |
| `hover_spec.lua` | the hover.nvim contribution — the `owner/repo` slug test, and that the source answers only for repositories reposcope has cached |
| `list_window_spec.lua` | `list_window`'s viewport handling: `reveal_line` scrolls a selection below the fold into view |
| `ui_config_spec.lua` | `reposcope.ui.config`, the shared layout/theme singleton every `*_config` module derives its own geometry from: `recompute()`'s editor-size math, `update_layout()`'s width/height pin that survives a later `recompute()` while its own col/row override does not, and `update_theme()`'s dark/light/custom/invalid branches |
| `init_spec.lua` | `setup()` with each optional step switched off, and a real `open_ui()`/`close_ui()` round trip |

## Findings pinned here

Four defects are pinned with `BUG:`-marked assertions rather than fixed, so a
change to any of them is a deliberate one. Each is described in full at the
assertion; in short:

1. **`clone_manager.lua` (all three providers) — the path guard and the mkdir
   are both dead code.** `vim.fn.isdirectory()` answers `0`/`1`, and `0` is
   truthy in Lua, so `not isdirectory(path)` is `false` for every input. The
   "Clone request: Invalid path" branch is unreachable, and so is
   `safe_mkdir(output_dir)` one line below it. Pinned in `clone_spec.lua`.
2. **`bindings/keymaps.lua` — `unset_prompt_keymaps()` removes nothing.** It
   clears by the exact tag `"reposcope_prompt"`, while registration tags each
   entry per field (`"reposcope_prompt_keywords"`, …). The mappings survive
   only because `close_ui()` deletes their buffers; the registry itself grows
   by one entry per mapping per field on every open/close cycle. Pinned in
   `bindings_spec.lua`.
3. **`utils/protection.lua` — `is_valid_path(path)` raises when its documented
   optional second argument is omitted.** `filename` is never assigned, the
   `nec_filename == false` early return does not fire for `nil`, and the error
   path concatenates the nil. No in-repo caller today; it is public API all the
   same. Pinned in `protection_spec.lua`.
4. **`ui/actions/readme_viewer.lua` — opening the viewer twice raises "Invalid
   buffer id".** `_prepare_readme_buffer` reuses the already-open buffer and
   hands it back; `_open_readme_window` then closes the previous window, which
   wipes that buffer (`bufhidden = "wipe"`), and passes the dead handle to
   `nvim_open_win` on the next line. The route there runs through (2): the
   guard that is meant to make this unreachable is `unset_prompt_keymaps()`.
   The reuse branch also restores `modifiable` without clearing `readonly`, so
   the write on the way emits `W10`. Pinned in `readme_views_spec.lua`.

Two further oddities are pinned as *documented behaviour*, not defects: the
GitHub search fetcher's "N repositories received" message collapses to the bare
count (`..` binds tighter than `or`), and `close_ui()` leaves dead buffer
handles in `ui_state.buffers` — harmless, because every reader validates first.

Two other defects this list used to carry here are fixed, not pinned, as of
the two commits right after this suite's initial round: `repository_fetcher.lua`
(GitHub and Codeberg) raising on a `vim.json.decode("null")` body is now the
same `type(parsed) ~= "table"` check the GitLab fetcher always used, and
GitLab's `PRIVATE-TOKEN` traveling in curl's argv was `lib.nvim`'s bug, fixed
upstream and caught up with here. Both specs now assert the corrected
behaviour instead of the old bug report — see `repository_fetcher_spec.lua`
and `request_tools_spec.lua`.

## Deliberately not covered

- **`@types/aliases.lua` and `@types/classes/*.lua`** (10 files) — pure
  `---@meta` annotations, no runtime code.
- **`plugin/reposcope.lua`** — a three-line `vim.health.registry` guard with no
  branch worth asserting; `health_spec.lua` covers what it registers.
- **`config/DEFAULTS.lua`** — a declarative table. Its values are asserted
  indirectly by every fallback in `config_spec`/`config_options_spec`.
- **`state/ui/stats_popup.lua`** — a two-field holder table.
- **`utils/spawn_env.lua`** — a single re-export of `lib.nvim.cross.run.env`;
  that it is what reaches the child is asserted in `request_tools_spec`.
- **`utils/stats.lua`'s `show_stats`/`close_stats`** — window choreography over
  `lib.nvim.window`; the two aggregations they display are covered in
  `metrics_spec`.
- **The window-building half of `ui/`** — `background_window`,
  `list/init`, `list_manager`, `preview/{init,manager,window,banner}`,
  `prompt/{init,buffers,layout,manager,focus,list_navigate,autocmds}` and the
  `*_config` geometry modules. These are `nvim_open_win` choreography with no
  return value to assert; `init_spec.lua` drives all of them end to end via a
  real `open_ui()`/`close_ui()` round trip, and the parts with real logic
  (`list_window`'s viewport, `prompt_config`'s field normalization,
  `prompt_input`'s collection) have their own specs.
- **`ui/preview/preview_image.lua` beyond `find_url`** — drawing needs
  images.nvim with remote images enabled and a real terminal graphics
  protocol.
- **The real requests and the real `git`** — every branch *around* them is
  covered through the seams listed above; only the syscall itself is absent,
  on purpose.

## Adding a spec

Write `TESTS/<name>_spec.lua` returning `function(H) ... end`, then list it in
`run.lua` at the layer it belongs to. `H` is the harness:

- assertions: `eq`, `ok`, `falsy`, `contains`, `excludes`, `has`, `lacks`
  (`has`/`lacks` are for list membership, e.g. argv tables)
- `with_stubs(stubs, reload, fn)` — see "No network, no processes" above
- `fixture(name)` — a scratch directory inside the repository, plus its cleanup
- `read(path)` — a file back as one string
- `index_of(list, value)`, `drain(ticks)` — argv lookups, and yielding to the
  scheduler so a `vim.schedule`d effect has happened
