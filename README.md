# reposcope.nvim
![Alpha](https://img.shields.io/badge/status-alpha-orange)
![License: MIT](https://img.shields.io/badge/license-MIT-blue.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)

⚠️ This plugin is in **alpha stage**. Expect breaking changes, missing features, and sharp edges.

```
 _ __   ___  _ __    ___   ___   ___   ___   _ __    ___
| '__| / _ \| '_ \  / _ \ / __| / __| / _ \ | '_ \  / _ \
| |   |  __/| |_) || (_) |\__ \| (__ | (_) || |_) ||  __/
|_|    \___|| .__/  \___/ |___/ \___| \___/ | .__/  \___|
            | |                             | |
            |_|                             |_|
```

Search and preview repositories from GitHub (and other code forges) directly inside Neovim — powered by Telescope.

---

## Features

- 🔍 Search public GitHub repositories by keyword or topic
- 📄 Preview the `README.md` content of each repo inline
- 🧩 Designed as a modular provider system (GitLab, Codeberg, etc. coming soon)
- 📦 Telescope-powered fuzzy search UI
- ⚙️ Low coupling, high cohesion — clean and extendable architecture
- 🔐 Supports GitHub API token authentication

---

## Roadmap

- [ ] GitHub repo search (basic)
- [ ] GitHub README preview (Base64 decode + render)
- [ ] Telescope UI integration
- [ ] GitHub topic filtering
- [ ] GitLab provider support
- [ ] Clone repo via `gh` or `git`
- [ ] Local cache support

---

## Installation

### With [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "yourname/reposcope.nvim",
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
  "yourname/reposcope.nvim",
  requires = {
    "nvim-lua/plenary.nvim",
    "nvim-telescope/telescope.nvim",
  },
  config = function()
    require("reposcope.init").setup()
  end,
}
```

---

## Usage

After installing and configuring, launch the UI via command:

```vim
:ReposcopeStart
```

Or map it in your Neovim config:

```lua
vim.keymap.set("n", "<leader>rs", function()
  vim.cmd("ReposcopeStart")
end, { desc = "Search GitHub repositories" })
```

### Closing the UI

The UI can be closed via:

* `<Esc>` (in any prompt or list window)
* `:ReposcopeClose` command

---

## Authentication

To use authenticated GitHub API requests (higher rate limits):

```sh
export GITHUB_TOKEN=ghp_your_token_here
```

This will be used internally for GitHub API access.

---

## Architecture

* `reposcope/init.lua` handles UI lifecycle: `setup`, `open_ui`, `close_ui`
* `reposcope/ui/*` contains modular window components (background, prompt, list, preview)
* Keymaps are centrally managed and tracked in `reposcope/keymaps.lua`
* User commands are registered via `reposcope/usercommands.lua`
* Provider logic is located in `reposcope/ui/prompt/input.lua`

## License

[MIT License © 2025](./LICENSE)

---

## Status, Development & Contribution

`reposcope.nvim` is under active development. Contributions, feature requests and issue reports are welcome!

Clone the repository and either symlink or load it into your Neovim runtime path.

---
