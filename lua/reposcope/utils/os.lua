---@module 'reposcope.utils.os'
---@brief Provides OS-specific utilities, such as opening URLs in the default web browser
--- Currently, it supports opening URLs in the default web browser on Linux, macOS, and Windows.

---@class OSUtils : OSUtilsModule
local M = {}

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Returns the raw `sysname` reported by `uv.os_uname()` (e.g. "Linux", "Darwin", "Windows_NT").
---@return string
local function sysname()
  ---@diagnostic disable-next-line vim.loop or vim.uv os_uname exists
  return vim.loop.os_uname().sysname
end

---Returns true when running on Windows. Central check to avoid ad-hoc
---`sysname:match("Windows")` calls scattered across the codebase.
---@return boolean
function M.is_windows()
  return sysname() == "Windows_NT"
end

--- Opens the given URL in the system's default web browser, cross-platform.
--- The URL is quoted so that special shell characters (e.g. `&` in query
--- strings) are not interpreted by the shell/cmd.exe.
---@param url string The URL to open
---@return nil
function M.open_url(url)
  local os_name = sysname()

  if os_name == "Linux" then
    vim.cmd("silent !xdg-open " .. vim.fn.shellescape(url) .. " &")
  elseif os_name == "Darwin" then -- macOS
    vim.cmd("silent !open " .. vim.fn.shellescape(url) .. " &")
  elseif os_name == "Windows_NT" then -- Windows
    -- The empty "" title argument is required by `start` when followed by a quoted URL.
    vim.cmd('silent !start "" "' .. url .. '"')
  else
    notify("[reposcope] Unsupported OS for opening URLs: " .. os_name, 4)
  end
end

return M
