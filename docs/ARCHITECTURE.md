# Architecture Overview

```
reposcope/
│
├── init.lua                 → Setup and UI lifecycle
├── config/                  → User options (init.lua) and defaults (DEFAULTS.lua)
├── bindings/                → Keymaps, user commands, top-level autocmds
├── ui/                      → Modular UI: prompt, list, preview, background
├── providers/               → GitHub (others coming soon)
├── cache/                   → In-memory and file-based caching
├── controllers/             → Unified dispatch: readme, repositories, clone
├── state/                   → Buffers, windows, user input state
├── network/                 → HTTP clients and request tools (curl, gh, ...)
├── utils/                   → Debug, protection, encoding, os-tools
```
