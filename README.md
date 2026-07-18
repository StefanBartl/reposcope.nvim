# reposcope.nvim

![version](https://img.shields.io/badge/version-0.1-blue.svg)
![State](https://img.shields.io/badge/status-beta-orange.svg)
![Lazy.nvim compatible](https://img.shields.io/badge/lazy.nvim-supported-success)
![Neovim](https://img.shields.io/badge/Neovim-0.9+-success.svg)
![Lua](https://img.shields.io/badge/language-Lua-yellow.svg)

> 🔧 Beta stage – under active development. Changes possible.

> 📁 Cloned a repo with Reposcope? Browse it locally with [filetree.nvim](https://github.com/StefanBartl/filetree.nvim).

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

## Quickstart

Install with [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "StefanBartl/reposcope.nvim",
  name = "reposcope",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  config = function()
    require("reposcope.init").setup({})
  end,
}
```

Then launch the UI:

```vim
:Reposcope start
```

---

## Documentation

- [Features](docs/FEATURES.md) — full feature list and a demo video.
- [Installation](docs/INSTALLATION.md) — install with Lazy.nvim or packer.nvim.
- [Configuration](docs/CONFIGURATION.md) — all available setup options and defaults.
- [Commands](docs/COMMANDS.md) — UI keymaps and the full `:Reposcope` subcommand reference.
- [Bindings Reference](docs/BINDINGS.md) — authoritative list of keymaps, user commands, and autocommands.
- [Authentication](docs/AUTHENTICATION.md) — using a `GITHUB_TOKEN` with the `gh` backend.
- [Architecture](docs/ARCHITECTURE.md) — module layout overview.
- [Development & Debugging](docs/DEVELOPMENT.md) — dev mode, logging, and debug file locations.
- [Roadmap](docs/ROADMAP.md) — shipped features and what's planned next.
- [Contributing](docs/CONTRIBUTING.md) — how to get involved.

---
