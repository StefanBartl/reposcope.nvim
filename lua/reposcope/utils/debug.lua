---@class ReposcopeDebug Debug utilities for inspecting UI-related buffers and windows.
---@field options DebugOptions Configurations options for debugging of reposcope
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field set_dev_mode fun(value: boolean): nil Sets the debug mode to a specific value
---@field toggle_dev_mode fun(): nil Toggle dev mode (standard: false)
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
local M = {}

---WATCH: Anything new to mention here?

---@class DebugOptions
---@field dev_mode boolean Enables developer mode (default: false)
M.options = {
  dev_mode = true, -- Print all notifys  
}

--- Dynamically provides access to debug_mode value via metatable.
--- The metatable ensures that access to debug_mode always returns the current value
setmetatable(M, {
  __index = function(_, key)
    -- If the requested key is 'dev_mode', return the current dev_mode value
    if key == "dev_mode" then
      return M.options.dev_mode
    end
  end
})

---Checks if dev mode is enabled
function M.is_dev_mode()
  return M.options.dev_mode
end

---Toggle dev mode config option 
function M.toggle_dev_mode()
  M.options.dev_mode = not M.options.dev_mode
end

--- Sets the debug mode to a specific value
function M.set_dev_mode(value)
  M.options.dev_mode = value
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
