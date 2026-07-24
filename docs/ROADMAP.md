# Roadmap

Record of shipped features, plus the backlog of planned features, user
commands, keymaps, and autocommands. For everything already implemented, see
[BINDINGS.md](BINDINGS.md).

## Table of Contents

- [1. Shipped](#1-shipped)
- [2. Planned Features](#2-planned-features)
- [3. Planned User Commands](#3-planned-user-commands)
- [4. Planned Keymaps](#4-planned-keymaps)
- [5. Planned Autocommands](#5-planned-autocommands)

---

## 1. Shipped

- [x] GitHub repository search (field-based)
- [x] GitHub README rendering (raw + API fallback)
- [x] Clone repo with tool of choice (`git`, `gh`, `curl`, `wget`)
- [x] Bulk-update all cloned repositories (`:Reposcope update`)
- [x] Git status overview of cloned repositories (`:Reposcope status`)
- [x] File-based README cache
- [x] Full UI (list, prompt, preview, background) in dynamic layout
- [x] Metrics, logging, and developer diagnostics
- [x] Viewer/editor for README content
- [x] Help docs via `:h reposcope`
- [x] GitLab provider support

---

## 2. Planned Features

- [ ] Codeberg provider support
- [ ] Persistent session save/restore (last search, filters, sort)

---

## 3. Planned User Commands

- [ ] `:Reposcope providers` – list available/active providers (GitHub, GitLab, Codeberg, ...)
- [ ] `:Reposcope session save|restore|clear` – manage persisted sessions

---

## 4. Planned Keymaps

- [ ] None currently planned — all keymaps are user-configurable and disableable,
  see [`bindings/keymaps.lua`](../lua/reposcope/bindings/keymaps.lua) and [BINDINGS.md](BINDINGS.md)

---

## 5. Planned Autocommands

- [ ] None currently planned
