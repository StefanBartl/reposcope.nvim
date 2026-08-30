> **Active development.** This repository is in its development phase — breaking changes are to be expected at any time. Pin a commit or tag if you depend on it.

# reposcope.nvim

> 📁 Cloned a repo with Reposcope? Browse it locally with [filetree.nvim](https://github.com/StefanBartl/filetree.nvim).

```
 _ __   ___  _ __    ___   ___   ___   ___   _ __    ___
| '__| / _ \| '_ \  / _ \ / __| / __| / _ \ | '_ \  / _ \
| |   |  __/| |_) || (_) |\__ \| (__ | (_) || |_) ||  __/
|_|    \___|| .__/  \___/ |___/ \___| \___/ | .__/  \___|
            | |                             | |
            |_|                             |_|
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)

Search, preview and clone repositories from GitHub, GitLab or Codeberg –
directly from inside Neovim. It doesn't stop at discovery: Reposcope also
manages what you've already cloned, with a bulk git status overview and
fetch+pull update across a whole folder of repos, plus filtering, sorting,
favorites and session persistence for your searches. Modular, minimal,
Telescope-inspired interface.

---

## Table of Contents

- [Capabilities](#capabilities)
- [Quickstart](#quickstart)
- [Documentation](#documentation)

---

## Capabilities

| Capability | What it does | Details |
| --- | --- | --- |
| `:Reposcope start` | Search/preview/clone repositories across GitHub, GitLab and Codeberg, with README caching and precaching | [Commands](docs/COMMANDS.md) |
| `:Reposcope status [dir]` | Git status overview (branch, ahead/behind, dirty) across a folder of cloned repos: push/pull/fetch a row inline, `m` to mark a set and act on all of them, or `gp`/`gP`/`gf`/`gu` for the whole folder | [Commands](docs/COMMANDS.md) |
| `:Reposcope update [dir]` | Bulk `git fetch` + fast-forward-only `pull` across a folder of cloned repos | [Commands](docs/COMMANDS.md) |
| `:Reposcope filter` / `filter-prompt` / `sort` | Filter and sort the current search results | [Commands](docs/COMMANDS.md) |
| `:Reposcope favorites` | Save favorite repositories, including a README snapshot for offline viewing | [Commands](docs/COMMANDS.md) |
| `:Reposcope session` | Persist/restore the last search, filter and sort mode across restarts | [Commands](docs/COMMANDS.md) |
| `:Reposcope queries` | Track and list your most-frequent searches | [Commands](docs/COMMANDS.md) |
| `:Reposcope providers` / `stats` / `toggle-dev` | List providers, request metrics, and developer/debug tooling | [Commands](docs/COMMANDS.md) |

---

## Quickstart

Install with [Lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "StefanBartl/reposcope.nvim",
  name = "reposcope",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {},
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
- [Contributing](docs/CONTRIBUTING.md) — how to get involved.

---

## License

MIT — see [LICENSE](LICENSE).
