---@module 'reposcope.utils.os'
---@brief Provides OS-specific utilities, such as opening URLs in the default web browser
--- Currently, it supports opening URLs in the default web browser on Linux, macOS, and Windows.

---@class OSUtils : OSUtilsModule
local M = {}

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


--- Opens the given URL in the system's default web browser, cross-platform.
---@param url string The URL to open
---@return nil
function M.open_url(url)
  ---@diagnostic disable-next-line vim.loop or vim.uv os_uname exists
  local os = vim.loop.os_uname().sysname

  if os == "Linux" then
    vim.cmd("silent !xdg-open " .. url .. " &")
  elseif os == "Darwin" then -- macOS
    vim.cmd("silent !open " .. url .. " &")
  elseif os == "Windows_NT" then -- Windows
    vim.cmd("silent !start " .. url)
  else
    notify("[reposcope] Unsupported OS for opening URLs: " .. os, 4)
  end
end

return M
