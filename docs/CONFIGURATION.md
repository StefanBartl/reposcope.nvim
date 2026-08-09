# Configuration

`reposcope.nvim` is fully configurable. You can start with the defaults:

```lua
require("reposcope").setup({})
```

Or define a custom setup with fine-grained control:

```lua
require("reposcope").setup({
  prompt_fields = {
    "prefix", "owner", "keywords", "language", "topic", "stars"
  },                                        -- Prompt fields shown to the user
  provider = "github",                      -- Which backend to use: "github" (default), "gitlab", "codeberg"
  request_tool = "curl",                    -- Tool for API requests: "gh", "curl", "wget" ("gh" only works with provider = "github")
  layout = "default",                       -- Currently only "default" supported
  github_token = os.getenv("GITHUB_TOKEN"), -- If higher API Limits neeeded set the token here. If that doesn't works: see docs/AUTHENTICATION.md
  gitlab_token = os.getenv("GITLAB_TOKEN"),     -- Same as github_token, for provider = "gitlab"
  codeberg_token = os.getenv("CODEBERG_TOKEN"), -- Same as github_token, for provider = "codeberg"
    keymaps = {
    open = "<leader>rs",                    -- Mapping to open the UI (set to false/"" to disable)
    close = "<leader>rc",                   -- Mapping to close the UI (set to false/"" to disable)
  },
  prompt_keymaps = {
    open_viewer = "<C-v>",                  -- Rebind or set to false/"" to disable; see docs/BINDINGS.md
    help = "?",                             -- Keymap cheatsheet (normal mode only)
  },
  prompt_prefix_symbol = " " .. "\u{f002}" .. " ", -- Symbol in the `prefix` field; needs a Nerd Font. Set e.g. "> " for plain terminals
  clone = {
    std_dir = "~/projects",                 -- Default directory to clone into
    type = "git",                           -- Clone method: "git", "gh", "wget", "curl"
  },
  metrics = true,                           -- Enables request timing and logging (for debugging)
  progress_style = "auto",                  -- Indicator for `:Reposcope update`/`status`; needs lib.nvim, no-op without it
  readme_precache_count = 5,                -- Pre-cache READMEs for this many top search results (0 disables)
  sidebar_enabled = true,                   -- Narrow left sidebar: active filter, sort mode, result count
})
```

---

## Available Options

| Option          | Type       | Description                                                        |
| --------------- | ---------- | ------------------------------------------------------------------ |
| `prompt_fields` | `string[]` | Controls which input fields appear in the prompt UI                |
| `provider`      | `string`   | Active backend: `"github"`, `"gitlab"`, or `"codeberg"`             |
| `request_tool`  | `string`   | CLI tool to fetch data: `"gh"`, `"curl"`, `"wget"` (`"gh"` only supports `provider = "github"`, others fall back to `curl`) |
| `gitlab_token`  | `string`   | GitLab personal access token, used when `provider = "gitlab"`      |
| `codeberg_token`| `string`   | Codeberg personal access token, used when `provider = "codeberg"`  |
| `layout`        | `string`   | UI layout style (currently only `"default"`)                       |
| `keymaps.open`  | `string\|false`   | Keymap to open Reposcope UI (`false`/`""` disables it)       |
| `keymaps.close` | `string\|false`   | Keymap to close the UI cleanly (`false`/`""` disables it)    |
| `prompt_keymaps`| `table`    | Per-action keymaps for the prompt buffers; see [BINDINGS.md](BINDINGS.md) |
| `prompt_prefix_symbol` | `string` | Symbol shown in the `prefix` field (default needs a Nerd Font; e.g. `"> "` for plain terminals) |
| `clone.std_dir` | `string`   | Base path for repository cloning                                   |
| `clone.type`    | `string`   | Tool used to perform clone: `"git"`, `"gh"`, `"wget"`, or `"curl"` |
| `metrics`       | `boolean`  | Enable internal request logging and performance tracking           |
| `progress_style`| `string`   | Progress indicator for the bulk repository commands; see [below](#progress-indicator) |
| `readme_precache_count` | `number` | After a search, pre-cache READMEs for this many top results in the background (`0` disables); see [README Caching](#readme-caching) |
| `sidebar_enabled` | `boolean` | Narrow left sidebar showing the active filter, sort mode, and result count (`false` reclaims the space for the list) |

> ℹ️ You can dynamically reload prompt fields with `:Reposcope prompt prefix topic`.

> ℹ️ GitLab's and Codeberg's search APIs only support a plain substring match
> (no `owner:`/`language:`-style qualifiers like GitHub's search) — with
> `provider = "gitlab"` or `provider = "codeberg"`, every non-empty prompt
> field is joined into one plain search string instead of being applied as a
> scoped filter.

---

## Progress Indicator

`:Reposcope update` and `:Reposcope status` walk a whole directory of clones and
run `git` once (or twice) per repository. Each individual call is quick, but over
a few dozen repositories that adds up to a wait long enough to look like a hang —
`update` in particular was silent between "Updating N repositories" and the final
summary, because its per-repository notifications are dev-mode only.

Both commands now report live progress through
[`lib.nvim.progress`](https://github.com/StefanBartl/lib.nvim/blob/main/lua/lib/nvim/progress/README.md),
which separates "an operation is running" from "how that is shown":

```lua
require("reposcope").setup({
  progress_style = "auto", -- "auto" | "notify" | "statusline" | "fidget" | "float" | "kit"
})
```

`lib.nvim` is an **optional** dependency. Without it installed the option is
silently a no-op and both commands behave exactly as before — no error, nothing
missing beyond the indicator itself.

| Style          | Behaviour                                                                 |
| -------------- | ------------------------------------------------------------------------- |
| `"auto"`       | Default. Prefers `fidget.nvim` when installed, else `vim.notify`.         |
| `"notify"`     | `vim.notify`; updated in place by backends that return an id (nvim-notify). |
| `"statusline"` | Draws nothing — publishes the text for your own statusline to read.       |
| `"fidget"`     | `fidget.nvim`'s LSP-style progress handles.                               |
| `"float"`      | Small floating window; focus it and press `<Esc>` to abort.               |
| `"kit"`        | Like `"float"`, themed via `lib.nvim.ui.kit`.                             |

The indicator is **delay-guarded**: it only becomes visible after ~150ms, so
`status` on two or three repositories never flashes any UI.

Cancelling (`"float"`/`"kit"`) stops `update` after the repository currently
being fetched, rather than killing `git` mid-write — the repositories already
updated stay updated, and the final summary reports the real count.

### With the `"statusline"` style

This style is headless by design: read the shared registry from your own
statusline component. It returns one entry per in-flight operation across *all*
plugins using `lib.nvim.progress`, so this snippet is not reposcope-specific:

```lua
local function progress_component()
  local ok, sl = pcall(require, "lib.nvim.progress.styles.statusline")
  if not ok then return "" end
  return table.concat(sl.active(), " | ") -- "" when nothing is running
end
```

---

## README Caching

READMEs are cached in two levels (RAM and file, surviving restarts) and, as of
this feature, also tracked for **freshness**:

- **Staleness detection.** Each cached README records the repository's
  `updated_at` (GitHub/Codeberg) or `last_activity_at` (GitLab, mapped to the
  same field) at cache time. On the next visit, if the repository's current
  value differs, the cache is treated as a miss and the README is re-fetched
  — a repo that hasn't changed is never re-fetched, one that has always gets
  fresh content. Repos/providers without the field fall back to the old
  "trust the cache" behavior (nothing to compare against).
- **RAM pre-warming.** On `setup()`, every already file-cached README is
  loaded into the RAM cache, so a fresh Neovim session doesn't pay a disk
  read on the first visit to a repository you'd already cached before.
- **Result pre-caching.** `readme_precache_count` (default `5`) — after a
  search, the top N results' READMEs are fetched in the background (RAM +
  file only, no preview/UI interaction), so scrolling through them feels
  instant instead of triggering a fetch per row. Set to `0` to disable.

```lua
require("reposcope").setup({
  readme_precache_count = 5, -- 0 disables pre-caching
})
```
