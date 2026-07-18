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
  provider = "github",                      -- Which backend to use: "github" (default), "gitlab" (planned)
  request_tool = "curl",                    -- Tool for API requests: "gh", "curl", "wget"
  layout = "default",                       -- Currently only "default" supported
  github_token = os.getenv("GITHUB_TOKEN"), -- If higher API Limits neeeded set the token here. If that doesn't works: see docs/AUTHENTICATION.md
    keymaps = {
    open = "<leader>rs",                    -- Mapping to open the UI (set to false/"" to disable)
    close = "<leader>rc",                   -- Mapping to close the UI (set to false/"" to disable)
  },
  prompt_keymaps = {
    open_viewer = "<C-v>",                  -- Rebind or set to false/"" to disable; see docs/BINDINGS.md
  },
  clone = {
    std_dir = "~/projects",                 -- Default directory to clone into
    type = "git",                           -- Clone method: "git", "gh", "wget", "curl"
  },
  metrics = true,                           -- Enables request timing and logging (for debugging)
})
```

---

## Available Options

| Option          | Type       | Description                                                        |
| --------------- | ---------- | ------------------------------------------------------------------ |
| `prompt_fields` | `string[]` | Controls which input fields appear in the prompt UI                |
| `provider`      | `string`   | Active backend (currently only `"github"` supported)               |
| `request_tool`  | `string`   | CLI tool to fetch data: `"gh"`, `"curl"`, `"wget"`                 |
| `layout`        | `string`   | UI layout style (currently only `"default"`)                       |
| `keymaps.open`  | `string\|false`   | Keymap to open Reposcope UI (`false`/`""` disables it)       |
| `keymaps.close` | `string\|false`   | Keymap to close the UI cleanly (`false`/`""` disables it)    |
| `prompt_keymaps`| `table`    | Per-action keymaps for the prompt buffers; see [BINDINGS.md](BINDINGS.md) |
| `clone.std_dir` | `string`   | Base path for repository cloning                                   |
| `clone.type`    | `string`   | Tool used to perform clone: `"git"`, `"gh"`, `"wget"`, or `"curl"` |
| `metrics`       | `boolean`  | Enable internal request logging and performance tracking           |

> ℹ️ You can dynamically reload prompt fields with `:Reposcope prompt prefix topic`.
