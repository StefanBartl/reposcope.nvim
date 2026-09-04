# Architecture Overview

```
reposcope/
│
├── init.lua                 → Setup and UI lifecycle
├── @types/                  → EmmyLua class and alias definitions
├── config/                  → User options (init.lua) and defaults (DEFAULTS.lua)
├── bindings/                → Keymaps, user commands, top-level autocmds
├── ui/                      → Modular UI: prompt, list, preview, background
├── providers/               → GitHub, GitLab, Codeberg
├── cache/                   → In-memory and file-based caching
├── controllers/             → Unified dispatch: readme, repositories, clone
├── state/                   → Buffers, windows, user input state
├── network/                 → HTTP clients and request tools (curl, gh, ...)
├── utils/                   → Debug, protection, encoding, os-tools
├── health.lua               → `:checkhealth reposcope`
└── hover.lua                → hover.nvim source for `owner/repo` slugs
```

Each provider mirrors the same shape — `query_builder.lua`, plus
`repositories/`, `readme/` and `clone/` subtrees — so adding a forge means
filling in that shape rather than touching the layers above it. The
controllers are the only place that knows which provider is active; the UI
never asks.

Every module carries EmmyLua annotations, and the types they refer to live
in `@types/` rather than beside their use, so `ConfigOptions` is defined
once and LuaLS can check `setup()` calls against it. `.luarc.json` is
committed, so the same diagnostics run in an editor as in CI.

Where the plugin writes: everything lands under
`stdpath("cache")/reposcope` — see
[`troubleshooting.md`](troubleshooting.md) for the individual paths.
