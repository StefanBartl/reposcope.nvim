--WATCH: If /config.set_state_path is the omly call to this file, then refactor /utils/utils.detect_os and /init.lua.setup() to /config.lua and delete this file

---@class SystemInformation
---@field os string|nil Represents the detected operating system ("win" for Windows, "unix" for Linux/macOS)
local M = {}

-- State table to store system information
M.state = {
  os = nil,
}

return M
