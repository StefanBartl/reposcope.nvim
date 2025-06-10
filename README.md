# reposcope.nvim
![version](https://img.shields.io/badge/version-0.1-blue.svg)
![State](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)

> 🔧 Beta stage – under active development. Changes possible.

```
 _ __   ___  _ __    ___   ___   ___   ___   _ __    ___
| '__| / _ \| '_ \  / _ \ / __| / __| / _ \ | '_ \  / _ \
| |   |  __/| |_) || (_) |\__ \| (__ | (_) || |_) ||  __/
|_|    \___|| .__/  \___/ |___/ \___| \___/ | .__/  \___|
            | |                             | |
            |_|                             |_|
```

Search, preview and clone GitHub repositories – directly from inside Neovim.
Modular, minimal, Telescope-inspired interface.

---

## Features

- 🔍 Dynamic GitHub repository search by topic, owner, language, etc.
- 📄 Live preview of `README.md` with inline Markdown rendering
- 🧠 Persistent README caching (RAM + file system)
- 🔧 Clone support: `git`, `gh`, `wget`, `curl`
- 🔁 Debounced README fetches to avoid redundant API calls
- 📦 Clean, fully modular architecture (UI, state, providers, controllers)
- 🧪 Strongly annotated with EmmyLua for LuaLS support
- 📊 Built-in request metrics and logging (optional toggle)
- 📑 README viewer (`<C-v>`) or README editor buffer (`<C-b>`)
- ⌨️ Keymaps for navigation, cloning, and UI control
- 📁 Customizable prompt fields (e.g. `prefix`, `keywords`, `owner`, ...)

---

## Roadmap

- [x] GitHub repository search (field-based)
- [x] GitHub README rendering (raw + API fallback)
- [x] Clone repo with tool of choice (`git`, `gh`, `curl`, `wget`)
- [x] File-based README cache
- [x] Full UI (list, prompt, preview, background) in dynamic layout
- [x] Metrics, logging, and developer diagnostics
- [x] Viewer/editor for README content
- [x] Help docs via `:h reposcope`
- [ ] GitLab + Codeberg provider support
- [ ] Persistent session save/restore

---

## Installation

### With [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "StefanBartl/reposcope.nvim",
  dependencies = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = true,
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "StefanBartl/reposcope.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("reposcope").setup()
  end,
}
```

---

## Configuration

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
  github_token = os.getenv("GITHUB_TOKEN"), -- If higher API Limits neeeded set the token here. If that doesn't works: [Authentication](#authentication)
    keymaps = {
    open = "<leader>rs",                    -- Mapping to open the UI
    close = "<leader>rc",                   -- Mapping to close the UI
  },
  clone = {
    std_dir = "~/projects",                 -- Default directory to clone into
    type = "git",                           -- Clone method: "git", "gh", "wget", "curl"
  },
  metrics = true,                           -- Enables request timing and logging (for debugging)
})
```

---

### Available Options

| Option          | Type       | Description                                                        |
| --------------- | ---------- | ------------------------------------------------------------------ |
| `prompt_fields` | `string[]` | Controls which input fields appear in the prompt UI                |
| `provider`      | `string`   | Active backend (currently only `"github"` supported)               |
| `request_tool`  | `string`   | CLI tool to fetch data: `"gh"`, `"curl"`, `"wget"`                 |
| `layout`        | `string`   | UI layout style (currently only `"default"`)                       |
| `keymaps.open`  | `string`   | Keymap to open Reposcope UI                                        |
| `keymaps.close` | `string`   | Keymap to close the UI cleanly                                     |
| `clone.std_dir` | `string`   | Base path for repository cloning                                   |
| `clone.type`    | `string`   | Tool used to perform clone: `"git"`, `"gh"`, `"wget"`, or `"curl"` |
| `metrics`       | `boolean`  | Enable internal request logging and performance tracking           |

> ℹ️ You can dynamically reload prompt fields with `:ReposcopePromptReload prefix topic`.

---

## Usage

Launch Reposcope UI:

```vim
:ReposcopeStart
```

Or map it in your Neovim config:

```lua
vim.keymap.set("n", "<leader>rs", function()
  vim.cmd("ReposcopeStart")
end, { desc = "Open Reposcope" })
```

### UI Keymaps

| Key           | Mode | Action                                |
| ------------- | ---- | ------------------------------------- |
| `<Esc>`       | any  | Close Reposcope UI                    |
| `<Up>/<Down>` | n/i  | Navigate repository list              |
| `<C-v>`       | n/i  | View README in floating window        |
| `<C-b>`       | n/i  | Open README in editable hidden buffer |
| `<C-c>`       | n/i  | Clone selected repository             |
| `<Tab>`       | i    | Cycle to next prompt field            |
| `<S-Tab>`     | i    | Cycle to previous prompt field        |

---

### Available Commands

**UI Lifecycle & Prompt Configuration**

| Command                      | Description                                                         |
| ---------------------------- | ------------------------------------------------------------------- |
| `:ReposcopeStart`            | Opens the Reposcope UI                                              |
| `:ReposcopeClose`            | Closes all Reposcope windows and buffers                            |
| `:ReposcopePromptReload ...` | Dynamically sets new prompt fields (e.g. `prefix`, `keywords`, ...) |

**Repository List: Sorting & Filtering**

| Command                        | Description                                                            |
| ------------------------------ | ---------------------------------------------------------------------- |
| `:ReposcopeSortPrompt`         | Opens an interactive selection menu to choose a sort mode              |
| `:ReposcopeFilterRepos {text}` | Filters the currently shown repositories by case-insensitive substring |
| `:ReposcopeFilterPrompt`       | Opens a floating prompt window to input a filter string interactively  |
| `:ReposcopeFilterClear`        | Clears any active filter and restores the full list of repositories    |

**Debugging, Stats & Metrics**

| Command                    | Description                                                              |
| -------------------------- | ------------------------------------------------------------------------ |
| `:ReposcopeToggleDev`      | Toggles developer mode (enables debug logging, internal info, etc.)      |
| `:ReposcopePrintDev`       | Prints whether developer mode is currently active                        |
| `:ReposcopeSkippedReadmes` | Shows number of skipped README fetches (debounced during fast scrolling) |
| `:ReposcopeStats`          | Displays collected request stats and metrics                             |

---

#### `:ReposcopePromptReload ...`

This user command updates the active prompt fields dynamically. It closes and reopens the Reposcope UI to apply the new configuration — the specified fields will then appear in the prompt layout.

> 🧠 Prompt fields must be chosen from: `prefix`, `keywords`, `owner`, `language`, `topic`, `stars`.
> If no fields are given, it defaults to: `keywords`, `owner`, `language`.

Example:

```vim
:ReposcopePromptReload keywords topic         "prompt without prefix: 
:ReposcopePromptReload prefix topic stars     "prompt with prefix, topice and stars field
:ReposcopePromptReload                        "resets to default
```

---

#### `:ReposcopeFilterRepos {text}`

Filters the current list of repositories using a case-insensitive substring
match.
The input is matched against the format: `owner/name: description`.

> If called without arguments, it resets the list to the original API result.

Examples:

```vim
:ReposcopeFilterRepos typescript bun "matches any repository with strings
:ReposcopeFilterRepos openai         "filter by organization or description
:ReposcopeFilterRepos                "clears filter and restores all results
```

---

#### `:ReposcopeFilterPrompt`

Opens a small floating input field where you can type a filter query.
The behavior is identical to `:ReposcopeFilterRepos`, but interactively.

Examples:

```vim
:ReposcopeFilterPrompt    "opens floating input to enter 'react', 'api', etc.
```

> Press `<Enter>` to confirm and filter; leave input empty to cancel.

---

## Authentication

`reposcope.nvim` works out of the box — **no authentication is required** for basic usage.

However, if you want to use the `gh` CLI as your request backend, you **must** set a valid `GITHUB_TOKEN` manually:

```sh
export GITHUB_TOKEN=ghp_your_token_here
```

⚠️ **Important:** Logged-in `gh` sessions (via `gh auth login`) are **not** accessible to child processes started via `uv.spawn()` inside Neovim. Without an explicit `GITHUB_TOKEN`, `gh`-based requests will silently fail.

As an alternative, you can use `curl` or `wget` without authentication — but you’ll have lower API rate limits.

---

### Recommended: Set it explicitly in `setup({ ... })`

In some systems or plugin managers, Neovim **does not inherit** environment variables defined in `.zshenv`, `.profile`, or GUI launch contexts.

To avoid issues, we recommend passing the token directly during setup:

```lua
require("reposcope").setup({
  github_token = os.getenv("GITHUB_TOKEN") or "gh__example_token", -- Explicitly forward the env variable
  ...
})
```

This ensures the token is correctly passed to internal request handlers, regardless of how Neovim was started.

If you do not set a token, `curl` or `wget` will still work — but you may hit GitHub's anonymous rate limits.

---

## Architecture Overview

```
reposcope/
│
├── init.lua                 → Setup and UI lifecycle
├── config.lua               → User options and dynamic resolution
├── ui/                      → Modular UI: prompt, list, preview, background
├── providers/               → GitHub (others coming soon)
├── cache/                   → In-memory and file-based caching
├── controllers/             → Unified dispatch: readme, repositories, clone
├── state/                   → Buffers, windows, user input state
├── network/                 → HTTP clients and request tools (curl, gh, ...)
├── utils/                   → Debug, protection, encoding, os-tools
```

---

## Development & Debugging

* Use `:ReposcopePromptReload prefix topic` to dynamically reload prompt fields
* Use `require("reposcope.utils.debug").notify(...)` for developer output
* Toggle metrics in config: `metrics = true`
* Debug file paths and logs are stored in:

  * `~/.local/share/nvim/reposcope/data/readme/`
  * `~/.local/share/nvim/reposcope/logs/request_log.json`

---

## License

[MIT © 2025 Stefan Bartl](./LICENSE)

---

## Contribution

Issues, suggestions and pull requests are welcome!
Clone, symlink into your Neovim config, and hack away.

```
git clone https://github.com/StefanBartl/reposcope.nvim ~/.config/nvim/reposcope.nvim
```

---
