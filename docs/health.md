# Health check

```vim
:checkhealth reposcope
```

Reposcope ships a health provider ([`lua/reposcope/health.lua`](../lua/reposcope/health.lua))
that reports what it found in the environment. Everything it checks is a
runtime fact, so it is the fastest answer to "why is nothing happening" —
see [troubleshooting.md](troubleshooting.md) for the symptoms it does not
cover.

## What it reports

| Check | What a failure means |
| --- | --- |
| Core modules loadable | An `ERROR` here means the plugin itself failed to load; nothing below it will be meaningful. Check `:messages` for the Lua error |
| `gh` / `curl` / `wget` installed | Each missing binary is reported individually. At least one must be present — that case is called out separately as its own `ERROR` |
| Configured request tool | `WARN` when `request_tool` is not one of `gh`, `curl`, `wget`. See [configuration.md](configuration.md) |
| `GITHUB_TOKEN` set | `WARN` only: unauthenticated requests work, at GitHub's lower anonymous rate limit. The `gh` backend needs it explicitly — see [authentication.md](authentication.md) |
| images.nvim present | `INFO` when it is missing: the `<C-p>` README image preview is unavailable and nothing else is affected |
| images.nvim remote images | `INFO` when installed but `display.remote.enabled` is off — the image preview needs it on. When on, the effective download cap is reported |
| `:Reposcope` command surface | Contributed by `lib.nvim`'s user-command composer: the subcommands actually registered |

## Notes on two of them

**The token warning is not an error on purpose.** Reposcope works with no
authentication at all through `curl` or `wget`; the token only raises the
rate limit. It becomes a hard requirement exactly once: with
`request_tool = "gh"`, where a `gh auth login` session is invisible to
Neovim's child processes.

**The download cap is reported, not enforced here.** The transfer happens
inside images.nvim's own `remote.fetch`, which reads its own config, so
this check states the effective value rather than applying one — a cap on
this side would refuse to draw bytes that had already been paid for. The
measured README image is 232 kB on average and 925 kB at worst, so a
`max_bytes` around 1 MB is comfortable; images.nvim's own default is 20 MB.
