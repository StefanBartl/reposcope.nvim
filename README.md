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
leaving Neovim.

It does not stop at discovery: reposcope also manages what you have already
cloned, with a bulk git-status overview and a fetch-and-pull update across a
whole folder of repositories — plus filtering, sorting, favorites and session
persistence for your searches.

---

## Table of contents

- [Documentation](#documentation)
- [What it does](#what-it-does)
- [Around it](#around-it)
- [Requirements](#requirements)
- [Installation](#installation)
- [Quickstart](#quickstart)
- [What you get with the defaults](#what-you-get-with-the-defaults)
- [Demo](#demo)
- [Health check](#health-check)
- [Contributing](#contributing)
- [Feedback](#feedback)
- [License](#license)

---

## Documentation

Start at [docs/README.md](docs/README.md), which says what is where and which
question each page answers.

- [Features](docs/FEATURES/README.md) — what shipped, per feature, with the module and config key behind it: [providers](docs/FEATURES/PROVIDERS.md), [the cache](docs/FEATURES/CACHE.md), [the UI](docs/FEATURES/UI.md).
- [Installation](docs/installation.md) — the spec, for lazy.nvim and packer.nvim.
- [Configuration](docs/configuration.md) — every `setup()` option with its default, the progress indicator, README caching, and the image preview.
- [Authentication](docs/authentication.md) — tokens per provider, and why a `gh auth login` session is not enough.
- [Command reference](docs/commands.md) — every `:Reposcope` subcommand, with syntax, flags and examples.
- [Bindings](docs/BINDINGS.md) — the authoritative table of keymaps, user commands and autocommands, each pointing at the code that defines it.
- [Workflow](docs/WORKFLOW.md) — how search, caching, cloning, bulk maintenance and sessions combine into a daily routine.
- [hover.nvim integration](docs/hover.md) — `owner/repo` under the cursor previewing that repository's cached README.
- [Health](docs/health.md) — what `:checkhealth reposcope` reports, and what to do about each warning.
- [Troubleshooting](docs/troubleshooting.md) — common symptoms, developer mode, where the cache and log files live, and how to force a fresh README.
- [Architecture](docs/architecture.md) — the module layout, and the shape every provider repeats.
- [Contributing](docs/CONTRIBUTING.md) — how to get involved.

`:help reposcope` is the same reference inside the editor.

---

## What it does

Finding a plugin, reading its README and cloning it is three context switches
out of the editor, and keeping thirty clones current is a fourth. This one
covers both ends of that.

| Area | Does |
| --- | --- |
| **Search** | Across GitHub, GitLab and Codeberg, in a modular Telescope-inspired interface, with the selected repository's README rendered in the preview as you move |
| **Clone** | Straight from the result list into your clone directory |
| **Maintenance** | A git-status overview across a whole folder of clones — branch, ahead/behind, dirty state, last-commit age — with push, pull and fetch per row, per marked set, or for the whole folder |
| **The cache** | READMEs are cached and precached, which is what makes moving through results feel instant and what the hover integration reads from |
| **Narrowing** | Filter and sort the current results, save favorites with an offline README snapshot, and track your most-frequent queries |
| **Sessions** | The last search, filter and sort mode restored across restarts |

Per-feature detail — the module, config key and command behind each — is in
[docs/FEATURES/](docs/FEATURES/README.md).

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
> [lib.nvim](https://github.com/StefanBartl/lib.nvim) is the one real plugin
> dependency — see [Requirements](#requirements).

---

## Requirements

| | |
| --- | --- |
| Neovim | **0.10+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | required — the command layer, notifications and the progress indicator |
| `gh`, `curl` or `wget` | required — at least one of the three on `$PATH`; `request_tool` picks which |
| `git` | required for cloning and for the status overview |

Optional, each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| `GITHUB_TOKEN` | Raises the GitHub API rate limit from 60 requests an hour to 5000. Not required, but the anonymous limit is easy to reach — see [docs/authentication.md](docs/authentication.md) |
| [hover.nvim](https://github.com/StefanBartl/hover.nvim) | `owner/repo` previews anywhere in any buffer |
| [images.nvim](https://github.com/StefanBartl/images.nvim) | The images a README references, drawn in the preview pane |

`:checkhealth reposcope` reports which request tools resolved, which one is
configured, whether a token is set, and how the image preview is wired.

---

## Installation

```lua
-- lazy.nvim
{
  "StefanBartl/reposcope.nvim",
  name = "reposcope",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  opts = {},
}
```

`event = "VeryLazy"` rather than `cmd`: the session restore and the query
tracking want to be in place before you reach for the picker. A packer.nvim
spec is in [docs/installation.md](docs/installation.md), and every option is in
[docs/configuration.md](docs/configuration.md).

---

## Quickstart

Open the picker:

```vim
:Reposcope start
```

Type into a prompt field, `<CR>` to search, `<Up>`/`<Down>` through the results
— the README of the selected repository renders in the preview as you move —
and `<C-c>` to clone the one you want. `<Tab>` cycles prompt fields, `<C-f>`
favorites a repository, `?` lists every key, `<Esc>` closes.

Then, later, for the clones you already have:

```vim
:Reposcope status
```

An interactive overview of every repository in your clone directory — branch,
ahead/behind, dirty state, last-commit age. Mark a set with `m` and `p`, `P` or
`f` to push, pull or fetch all of them; `gu` updates the whole folder.

Verify your setup any time with:

```vim
:checkhealth reposcope
```

---

## What you get with the defaults

| Command | Does |
| --- | --- |
| `:Reposcope start` | Search, preview and clone across GitHub, GitLab and Codeberg, with README caching and precaching |
| `:Reposcope status [dir]` | The git-status overview across a folder of clones; push, pull or fetch a row inline, `m` to mark a set, or `gp` / `gP` / `gf` / `gu` for the whole folder |
| `:Reposcope update [dir]` | Bulk `git fetch` plus a fast-forward-only `pull` across a folder |
| `:Reposcope filter` / `filter-prompt` / `sort` | Narrow and reorder the current results |
| `:Reposcope favorites` | Saved repositories, including a README snapshot for offline viewing |
| `:Reposcope session` | The last search, filter and sort mode, across restarts |
| `:Reposcope queries` | Your most-frequent searches |
| `:Reposcope providers` / `stats` / `toggle-dev` | The provider list, request metrics, and the developer tooling |
| `owner/repo` under the cursor | With [hover.nvim](https://github.com/StefanBartl/hover.nvim) installed, previews that repository's cached README — anywhere, not just in the picker |

The full subcommand reference is [docs/commands.md](docs/commands.md), and
every key is [docs/BINDINGS.md](docs/BINDINGS.md).

---

## Demo

https://github.com/user-attachments/assets/85dece1d-d755-4de9-9cd1-84a751901fc2

---

## Health check

```vim
:checkhealth reposcope
```

One section, and it answers the two questions that actually break a session:
which of `gh`, `curl` and `wget` resolved (only one is needed, so a missing
one is information rather than a failure) and whether `GITHUB_TOKEN` is set —
without it you get 60 API requests an hour instead of 5000. It also reports how
the images.nvim preview is configured, including the download cap, which lives
in that plugin rather than this one. [docs/health.md](docs/health.md) says what
to do about each warning.

---

## Contributing

Clone the repository and either symlink it or add it to your runtime path.
[docs/CONTRIBUTING.md](docs/CONTRIBUTING.md) has the ground rules;
[docs/architecture.md](docs/architecture.md) is the module layout and the shape
every provider repeats, and [TESTS/README.md](TESTS/README.md) is the headless
spec suite.

Pull requests very welcome.

---

## Feedback

Your feedback is very welcome. Use the
[issue tracker](https://github.com/StefanBartl/reposcope.nvim/issues) to report
bugs, suggest features or ask usage questions; anything more open-ended fits a
[discussion](https://github.com/StefanBartl/reposcope.nvim/discussions).

If you find this plugin useful, a ⭐ on GitHub supports its development.

---

## License

MIT — see [LICENSE](LICENSE).
