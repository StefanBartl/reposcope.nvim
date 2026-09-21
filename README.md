> **Beta stage — active development.** This repository is past its first shape and in
> active use, but the surface is not frozen: breaking changes are still possible. Pin a
> commit or tag if you depend on it.

# reposcope.nvim

```
 _ __   ___  _ __    ___   ___   ___   ___   _ __    ___
| '__| / _ \| '_ \  / _ \ / __| / __| / _ \ | '_ \  / _ \
| |   |  __/| |_) || (_) |\__ \| (__ | (_) || |_) ||  __/
|_|    \___|| .__/  \___/ |___/ \___| \___/ | .__/  \___|
            | |                             | |
            |_|                             |_|     .nvim
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-beta-orange)
[![CI](https://github.com/StefanBartl/reposcope.nvim/actions/workflows/ci.yml/badge.svg)](https://github.com/StefanBartl/reposcope.nvim/actions/workflows/ci.yml)

Search, preview and clone repositories from GitHub, GitLab or Codeberg without
leaving Neovim. It does not stop at discovery: reposcope also manages what you
have already cloned, with a bulk git dashboard and a fetch-and-pull
update across a whole folder of repositories — plus filtering, sorting,
favorites and session persistence for your searches.

---

## Around it

> **[filetree.nvim](https://github.com/StefanBartl/filetree.nvim)** — once a
> repository is cloned, this is how you read it: a file tree over the clone
> without leaving Neovim.
>
> **[hover.nvim](https://github.com/StefanBartl/hover.nvim)** — takes the
> README cache out of the picker: resting the cursor on `owner/repo` anywhere
> previews that repository, in a plugin spec or a note.
>
> **[images.nvim](https://github.com/StefanBartl/images.nvim)** — draws the
> screenshot or demo GIF a README references over the preview pane, instead of
> leaving you with link text.
>
> All three are soft: without them everything else works unchanged.
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) and
> [ui.nvim](https://github.com/StefanBartl/ui.nvim) are the real plugin
> dependencies — see [Requirements](docs/requirements.md).

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

### The Basics

- [Requirements](docs/requirements.md) — Neovim version, required plugins and CLI tools.
- [Installation](docs/installation.md) — the spec, for lazy.nvim and packer.nvim.
- [Quickstart](docs/quickstart.md) — the first thing to run after installing, with the demo.

### Configuration

- [What you get with the defaults](docs/what-you-get.md) — the full command surface at a glance.
- [All options](docs/configuration.md) — every `setup()` option with its default, the progress indicator, README caching, and the image preview.
- [Authentication](docs/authentication.md) — tokens per provider, and why a `gh auth login` session is not enough.
- [Command reference](docs/commands.md) — every `:Reposcope` subcommand, with syntax, flags and examples.
- [Bindings](docs/BINDINGS.md) — the authoritative table of keymaps, user commands and autocommands, each pointing at the code that defines it.

### The Rest

- [Features](docs/FEATURES/README.md) — what shipped, per feature, with the module and config key behind it: [providers](docs/FEATURES/PROVIDERS.md), [the cache](docs/FEATURES/CACHE.md), [the UI](docs/FEATURES/UI.md).
- [Workflow](docs/WORKFLOW.md) — how search, caching, cloning, bulk maintenance and sessions combine into a daily routine.
- [hover.nvim integration](docs/hover.md) — `owner/repo` under the cursor previewing that repository's cached README.
- [Health check](docs/health.md) — what `:checkhealth reposcope` reports, and what to do about each warning.
- [Troubleshooting](docs/troubleshooting.md) — common symptoms, developer mode, where the cache and log files live, and how to force a fresh README.
- [Architecture](docs/architecture.md) — the module layout, and the shape every provider repeats.
- [Contributing](docs/CONTRIBUTING.md) — how to get involved.
- [Feedback](https://github.com/StefanBartl/reposcope.nvim/issues) — bugs, feature requests and usage questions; broader discussion in [Discussions](https://github.com/StefanBartl/reposcope.nvim/discussions).

`:help reposcope` is the same reference inside the editor.

---

## License

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)

reposcope.nvim is released under the [MIT License](https://opensource.org/licenses/MIT).
