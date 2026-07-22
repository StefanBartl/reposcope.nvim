---@module 'reposcope.utils.os'
---@brief Provides OS-specific utilities, such as opening URLs in the default web browser
--- Currently, it supports opening URLs in the default web browser on Linux, macOS, and Windows.

---@class OSUtils : OSUtilsModule
local M = {}

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
local system_opener = require("lib.nvim.fs.open.url.system_opener")

---Returns true when running on Windows. Central check to avoid ad-hoc
---`sysname:match("Windows")` calls scattered across the codebase.
---@return boolean
function M.is_windows()
  return require("lib.nvim.cross.platform.is_windows")()
end

--- Opens the given URL in the system's default web browser, cross-platform.
---@param url string The URL to open
---@return nil
function M.open_url(url)
  local ok = system_opener.open(url)
  if not ok then
    local os_name = vim.uv.os_uname().sysname
    notify("[reposcope] Unsupported OS for opening URLs: " .. os_name, 4)
  end
end

return M
