# reposcope.nvim

```
 _ __   ___  _ __    ___   ___   ___   ___   _ __    ___
| '__| / _ \| '_ \  / _ \ / __| / __| / _ \ | '_ \  / _ \
| |   |  __/| |_) || (_) |\__ \| (__ | (_) || |_) ||  __/
|_|    \___|| .__/  \___/ |___/ \___| \___/ | .__/  \___|
            | |                             | |
            |_|                             |_|
```

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/Neovim-0.10%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)
[![Lua](https://img.shields.io/badge/Lua-5.1%2FLuaJIT-2C2D72?logo=lua&logoColor=white)](https://www.lua.org)
![Status](https://img.shields.io/badge/status-alpha-red)

Search, preview and clone repositories from GitHub, GitLab or Codeberg –
directly from inside Neovim. It doesn't stop at discovery: Reposcope also
manages what you've already cloned, with a bulk git status overview and
fetch+pull update across a whole folder of repos, plus filtering, sorting,
favorites and session persistence for your searches. Modular, minimal,
Telescope-inspired interface.

> **Alpha stage — active development.** This repository is in its development
> phase — breaking changes are to be expected at any time. Pin a commit or tag
> if you depend on it.

---

## Around it

Three plugins that pair with this one, and what each adds:

- **[filetree.nvim](https://github.com/StefanBartl/filetree.nvim)** — once
  a repository is cloned, this is how you read it: a file tree over the
  clone without leaving Neovim.
- **[hover.nvim](https://github.com/StefanBartl/hover.nvim)** — takes the
  README cache out of the picker: resting the cursor on `owner/repo`
  anywhere previews that repository, in a plugin spec or a note.
- **[images.nvim](https://github.com/StefanBartl/images.nvim)** — draws the
  screenshot or demo GIF a README references over the preview pane, instead
  of leaving you with link text.

Both hover.nvim and images.nvim are soft: without them everything else
works unchanged. [`lib.nvim`](https://github.com/StefanBartl/lib.nvim) is
the one real dependency — see [Installation](#installation).

---

## Demo

https://github.com/user-attachments/assets/85dece1d-d755-4de9-9cd1-84a751901fc2

---

## Installation

Requires Neovim 0.10+, [`lib.nvim`](https://github.com/StefanBartl/lib.nvim),
and at least one of `gh`, `curl` or `wget` on `$PATH`. With
[lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "StefanBartl/reposcope.nvim",
  name = "reposcope",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

A packer.nvim spec and the full option list are in
[docs/installation.md](docs/installation.md) and
[docs/configuration.md](docs/configuration.md). `:checkhealth reposcope`
reports whether the request tools and tokens are in place.

---

## Quickstart

```vim
:Reposcope start
```

Type into a prompt field, `<CR>` to search, `<Up>`/`<Down>` through the
results — the README of the selected repository renders in the preview as
you move — and `<C-c>` to clone the one you want. `<Tab>` cycles prompt
fields, `<C-f>` favorites a repository, `?` lists every key, `<Esc>` closes.

Then, later:

```vim
:Reposcope status
```

An interactive overview of every repository in your clone directory —
branch, ahead/behind, dirty state, last-commit age. Mark a set with `m` and
`p`/`P`/`f` push, pull or fetch all of them; `gu` updates the whole folder.

---

## Capabilities

| Capability | What it does | Details |
| --- | --- | --- |
| `:Reposcope start` | Search/preview/clone repositories across GitHub, GitLab and Codeberg, with README caching and precaching | [Commands](docs/commands.md) |
| `:Reposcope status [dir]` | Git status overview (branch, ahead/behind, dirty) across a folder of cloned repos: push/pull/fetch a row inline, `m` to mark a set and act on all of them, or `gp`/`gP`/`gf`/`gu` for the whole folder | [Commands](docs/commands.md) |
| `:Reposcope update [dir]` | Bulk `git fetch` + fast-forward-only `pull` across a folder of cloned repos | [Commands](docs/commands.md) |
| `:Reposcope filter` / `filter-prompt` / `sort` | Filter and sort the current search results | [Commands](docs/commands.md) |
| `:Reposcope favorites` | Save favorite repositories, including a README snapshot for offline viewing | [Commands](docs/commands.md) |
| `:Reposcope session` | Persist/restore the last search, filter and sort mode across restarts | [Commands](docs/commands.md) |
| `:Reposcope queries` | Track and list your most-frequent searches | [Commands](docs/commands.md) |
| `owner/repo` hover | With [hover.nvim](https://github.com/StefanBartl/hover.nvim) installed, resting the cursor on a slug previews that repository's cached README — anywhere, not just in the picker | [hover.nvim integration](docs/hover.md) |
| `:Reposcope providers` / `stats` / `toggle-dev` | List providers, request metrics, and developer/debug tooling | [Commands](docs/commands.md) |

Per-feature detail — the module, config key and command behind each — is in
[docs/FEATURES/](docs/FEATURES/README.md).

---

## Documentation

[docs/README.md](docs/README.md) is the index. The pages most people want
first:

- [Workflow](docs/WORKFLOW.md) — how the pieces combine into a daily routine.
- [Configuration](docs/configuration.md) — every option, with its default.
- [Commands](docs/commands.md) — the full `:Reposcope` subcommand reference.
- [Bindings](docs/BINDINGS.md) — keymaps, user commands and autocommands.
- [Troubleshooting](docs/troubleshooting.md) — dev mode, log and cache paths.

`:h reposcope` covers the same ground without leaving the editor.

---

## License

MIT — see [LICENSE](LICENSE).
