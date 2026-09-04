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
  github_token = os.getenv("GITHUB_TOKEN"), -- If higher API Limits neeeded set the token here. If that doesn't works: see docs/authentication.md
  gitlab_token = os.getenv("GITLAB_TOKEN"),     -- Same as github_token, for provider = "gitlab"
  codeberg_token = os.getenv("CODEBERG_TOKEN"), -- Same as github_token, for provider = "codeberg"
  results_limit = 25,                       -- Maximum number of search results per query
  hover = true,                             -- Register the hover.nvim source; no-op without hover.nvim (see docs/hover.md)
  keymaps = {
    open = "<leader>rs",                    -- Mapping to open the UI (set to false/"" to disable)
    close = "<leader>rc",                   -- Mapping to close the UI (set to false/"" to disable)
  },
  prompt_keymaps = {
    open_viewer = "<C-v>",                  -- Rebind or set to false/"" to disable; see docs/BINDINGS.md
    preview_image = "<C-p>",                -- README image over the preview; needs images.nvim (see below)
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
})
```

---

## Available Options

Every key `setup()` accepts, with the value it has when you don't pass one.
The authoritative list is
[`lua/reposcope/config/DEFAULTS.lua`](../lua/reposcope/config/DEFAULTS.lua),
typed as `ConfigOptions` in
[`lua/reposcope/@types/classes/configs.lua`](../lua/reposcope/@types/classes/configs.lua).

| Option | Type | Default | Description |
| --- | --- | --- | --- |
| `prompt_fields` | `string[]` | `{ "prefix", "keywords", "owner", "language" }` | Which input fields appear in the prompt UI. Choose from `prefix`, `keywords`, `owner`, `language`, `topic`, `stars` |
| `provider` | `string` | `"github"` | Active backend: `"github"`, `"gitlab"`, or `"codeberg"` |
| `request_tool` | `string` | `"gh"` | CLI tool to fetch data: `"gh"`, `"curl"`, `"wget"` (`"gh"` only supports `provider = "github"`, others fall back to `curl`). Note `"gh"` needs an explicit token — see [authentication.md](authentication.md) |
| `preferred_requesters` | `string[]` | `{ "gh", "curl", "wget" }` | Fallback order tried when `request_tool` is unavailable |
| `github_token` | `string` | `$GITHUB_TOKEN` or `""` | GitHub personal access token; raises the API rate limit and is required for the `gh` backend |
| `gitlab_token` | `string` | `$GITLAB_TOKEN` or `""` | GitLab personal access token, used when `provider = "gitlab"` |
| `codeberg_token` | `string` | `$CODEBERG_TOKEN` or `""` | Codeberg personal access token, used when `provider = "codeberg"` |
| `results_limit` | `number` | `25` | Maximum number of search results requested per query |
| `hover` | `boolean` | `true` | Register a [hover.nvim](https://github.com/StefanBartl/hover.nvim) source so `owner/repo` under the cursor previews that repository's cached README. A no-op without hover.nvim; see [hover.md](hover.md) |
| `layout` | `string` | `"default"` | UI layout style (currently only `"default"`) |
| `keymaps.open` | `string\|false` | `"<leader>rs"` | Keymap to open the Reposcope UI (`false`/`""` disables it) |
| `keymaps.close` | `string\|false` | `"<leader>rc"` | Keymap to close the UI cleanly (`false`/`""` disables it) |
| `keymap_opts` | `table` | `{ silent = true, noremap = true }` | Options passed to the two global keymaps above |
| `prompt_keymaps` | `table` | see [BINDINGS.md](BINDINGS.md#12-prompt-buffers) | Per-action keymaps for the prompt buffers; set an action to `false`/`""` to disable it |
| `prompt_prefix_symbol` | `string` | a Nerd Font glyph | Symbol shown in the `prefix` field; e.g. `"> "` for terminals without an icon font |
| `clone.std_dir` | `string` | `$REPOS_DIR` or `"~/temp"` | Base path for cloning — and the default target of `:Reposcope status`/`update` |
| `clone.type` | `string` | `""` (→ `git`) | Tool used to perform the clone: `""`/`"git"`, `"gh"`, `"wget"`, or `"curl"` (the latter two pull a `.zip`) |
| `metrics` | `boolean` | `false` | Enable internal request logging and performance tracking; see [troubleshooting.md](troubleshooting.md) |
| `log_max` | `number` | `1000` | Cap on the request log's size, in entries |
| `progress_style` | `string` | `"auto"` | Progress indicator for the bulk repository commands; see [below](#progress-indicator) |
| `readme_precache_count` | `number` | `5` | After a search, pre-cache READMEs for this many top results in the background (`0` disables); see [README Caching](#readme-caching) |

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
and `update`'s per-repository notifications are dev-mode only, so without an
indicator there is nothing between "Updating N repositories" and the final
summary.

Both commands report live progress through
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

---

## README Image Preview

`<C-p>` in the prompt draws the screenshot or demo GIF a repository's README
references over the preview pane. It is a **soft dependency** on
[images.nvim](https://github.com/StefanBartl/images.nvim): without it every
other part of Reposcope works unchanged, and the key says what is missing.

```lua
require("reposcope").setup({
  prompt_keymaps = {
    preview_image = "<C-p>", -- false/"" disables the action entirely
  },
})
```

images.nvim needs remote images turned on — they are off by default there, on
the same privacy grounds mail clients block external images:

```lua
require("images").setup({
  display = {
    remote = {
      enabled = true,
      -- The download cap for one image. images.nvim's default is 20 MB, which
      -- is sane for a local hover and generous for a preview pane: README
      -- images measured 232 kB on average and 925 kB worst case.
      max_bytes = 1024 * 1024,
    },
  },
})
```

**Why a keypress and not part of the preview.** Measured on 2026-08-29 over 25
repositories (20 widely-used Neovim plugins plus five of this author's): only
**8 of 25** carried a real image once badges were excluded, and the ones that
did cost **883 ms and 232 kB on average**. That is a reasonable price for
something asked for and the wrong one for something that fires because the
selection moved.

Finding out that a repository has *no* image costs nothing at all: the check
runs against the README already sitting in Reposcope's own cache, so the
two-thirds case is answered locally with no request. Nothing is fetched until
`<C-p>` is pressed.

**No cache is added for this.** The image itself persists in images.nvim's
SHA256-keyed cache across restarts, and the detection result is derived from a
README this plugin already caches on disk — caching "this repository has no
image" would cache something that is free to recompute.

`:checkhealth reposcope` reports whether images.nvim is installed, whether
remote images are enabled, and the effective download cap.

> ℹ️ GitHub's **social preview card** was measured alongside this and
> rejected: `opengraph.githubassets.com` allows 100 unauthenticated requests
> per IP and then answers `429` with `Retry-After: 900`. `readme_precache_count`
> alone spends 5 of those per search.
