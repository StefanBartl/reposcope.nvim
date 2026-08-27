---@module 'reposcope.utils.spawn_env'
---@brief Completed subprocess environment for `gh`/`curl`/`wget`, in the
---array format `lib.nvim.cross.uv.spawn_capture` (raw libuv `uv.spawn`)
---expects.
---@description
--- A subprocess started via libuv inherits exactly Neovim's own process
--- environment, not an interactive login shell's: `PATH` can be missing
--- version-manager entries, and `gh`'s OS-keyring lookup depends on session
--- variables (`DBUS_SESSION_BUS_ADDRESS`, the macOS login-session binding,
--- the Windows user context) that a non-login Neovim start never received.
--- `lib.nvim.cross.run.env` fixes exactly this: `.array()` is the
--- array-of-`"KEY=VALUE"` shape `spawn_capture` wants (`build()` itself
--- returns the `{ [key] = value }` dict `vim.system`/`jobstart` want), so
--- `gh.lua`/`curl.lua`/`wget.lua` don't each hand-roll the conversion.

local M = {}

M.array = require("lib.nvim.cross.run.env").array

return M
