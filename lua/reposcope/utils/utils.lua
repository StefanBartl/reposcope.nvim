---@class Utils
---@field detect_os fun()nil Set state information about used OS
local M = {}

-- Import the state module to set OS information
local system = require("reposcope.state.system")

---Detect the correct state path based on the OS
---Sets the OS type in the global system state (either "win" for Windows or "unix" for Linux/macOS).
function M.detect_os()
  if vim.fn.has("win32") == 1 or vim.fn.has("win64") == 1 then
    system.os = "win"
  else
    system.os = "unix"
  end
end

return M
