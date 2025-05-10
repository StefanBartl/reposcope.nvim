---@class ReposcopeDebug Debug utilities for inspecting UI-related buffers and windows.
---@field options DebugOptions Configurations options for debugging of reposcope
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
---@field toggle_dev_mode fun(): nil Toggle dev mode (standard: false)
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
local M = {}

---WATCH: Anything new to mention here?

---@class DebugOptions
---@field dev_mode boolean Enables developer mode (default: false)
M.options = {
  dev_mode = true, -- Print all notifys  
}

---Toggle dev mode config option 
function M.toggle_dev_mode()
  M.options.dev_mode = not M.options.dev_mode
end

---Checks if dev mode is enabled
function M.is_dev_mode()
  return M.options.dev_mode
end

---Sends a notification message with an optional log level.
---@param message string The notification message
---@param level? number Optional vim.log.levels (default: INFO)
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  if M.is_dev_mode() or level >= vim.log.levels.WARN then
    vim.schedule(function()
      vim.notify(message, level)
    end)
  end
end

return M
