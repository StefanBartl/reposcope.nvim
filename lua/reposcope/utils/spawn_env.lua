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
--- `lib.nvim.cross.run.env` fixes exactly this, but `build()` returns a
--- `{ [key] = value }` dict — libuv's own `env` spawn option is an array of
--- `"KEY=VALUE"` strings, so `spawn_capture` (see its own doc comment)
--- passes `opts.env` straight through, unconverted. This module is the one
--- place that does the dict->array conversion, so `gh.lua`/`curl.lua`/
--- `wget.lua` don't each hand-roll it.

local M = {}

---Build the completed environment as an array of `"KEY=VALUE"` strings,
---ready for `spawn_capture`'s `opts.env`.
---@param vars? table<string, string> Explicit overrides, applied last (e.g. GITHUB_TOKEN)
---@return string[]
function M.array(vars)
  local env = require("lib.nvim.cross.run.env").build({ vars = vars })
  local out = {}
  for k, v in pairs(env) do
    out[#out + 1] = k .. "=" .. v
  end
  return out
end

return M
