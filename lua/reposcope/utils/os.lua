local M = {}

local debug =require("reposcope.utils.debug")

--- Opens the given URL in the system's default web browser, cross-platform.
---@param url string The URL to open
function M.open_url(url)
  local os = vim.loop.os_uname().sysname

  if os == "Linux" then
    vim.cmd("silent !xdg-open " .. url .. " &")
  elseif os == "Darwin" then -- macOS
    vim.cmd("silent !open " .. url .. " &")
  elseif os == "Windows_NT" then -- Windows
    vim.cmd("silent !start " .. url)
  else
    debug.notify("[reposcope] Unsupported OS for opening URLs: " .. os, 4)
  end
end


return M
