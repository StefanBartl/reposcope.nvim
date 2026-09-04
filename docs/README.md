# reposcope.nvim documentation

Start with the [README](../README.md) for what the plugin is. This index is
for finding the page that answers a specific question.

## Getting it running

| Page | Answers |
| --- | --- |
| [installation.md](installation.md) | The plugin spec, for lazy.nvim and packer.nvim |
| [configuration.md](configuration.md) | Every `setup()` option with its default, the progress indicator, README caching, and the image preview |
| [authentication.md](authentication.md) | Tokens per provider, and why a `gh auth login` session is not enough |

## Using it

| Page | Answers |
| --- | --- |
| [WORKFLOW.md](WORKFLOW.md) | How search, caching, cloning, bulk maintenance and sessions combine into a daily routine — the narrative, not the reference |
| [commands.md](commands.md) | Every `:Reposcope` subcommand, with syntax, flags and examples |
| [BINDINGS.md](BINDINGS.md) | The authoritative table of keymaps, user commands and autocommands, each pointing at the code that defines it |
| [FEATURES/](FEATURES/README.md) | What shipped, per feature, with the module and config key behind it |
| [hover.md](hover.md) | The hover.nvim integration: `owner/repo` under the cursor previews that repository's cached README |

## When it misbehaves

| Page | Answers |
| --- | --- |
| [troubleshooting.md](troubleshooting.md) | Common symptoms, developer mode, where the cache and log files live, and how to force a fresh README |
| [health.md](health.md) | What `:checkhealth reposcope` reports, and what to do about each warning |

## Working on it

| Page | Answers |
| --- | --- |
| [architecture.md](architecture.md) | The module layout and the shape every provider repeats |
| [CONTRIBUTING.md](CONTRIBUTING.md) | How to get involved |
| [../TESTS/README.md](../TESTS/README.md) | The headless spec suite: how to run it, what each spec covers, how to add one |

There is also a Vim help file — `:h reposcope` — which covers the same
ground as `configuration.md`, `commands.md` and `authentication.md` without
leaving the editor.

## Not in this index

`docs/map/` is a generated module map (`:DocMap` rebuilds it from the
current tree). It is gitignored on purpose: a committed copy is stale the
moment anything it describes changes, and nothing here gates that. Nothing
links to it, and nothing should.
