---@class ReposcopeDebug Debug utilities for inspecting UI-related buffers and windows.
---@field options DebugOptions Configurations options for debugging of reposcope
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field set_dev_mode fun(value: boolean): nil Sets the debug mode to a specific value
---@field toggle_dev_mode fun(): nil Toggle dev mode (standard: false)
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
---@field debugf fun(msg: string, level?: number, log_level?: number, schedule?: boolean): nil Enhanced debugging function for logging
---@field print_win_buf_state fun(): nil Prints actual state for debugging to the console
local M = {}

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
  level = level or 2
  if M.is_dev_mode() or level >= 3 then
    vim.schedule(function()
      vim.notify(message, level)
    end)
  end
end

---Enhanced Debugging Function for Flexible Logging
---@param msg string The debug message to display
---@param level number? The stack level to analyze (default is 2)
---@param log_level number? The log level (DEBUG by default)
---@param schedule boolean? Optional: Use vim.schedule for async notification
function M.debugf(msg, level, log_level, schedule)
  if M.is_dev_mode() then
    level = level or 2
    log_level = log_level or 1

    -- Fetching detailed caller information
    local info = debug.getinfo(level, "nSl")
    local function_name = info.name or "<unknown>"
    local source = info.short_src or info.source or "<unknown>"
    local line = info.currentline or -1

    -- Format the debug message
    local dmsg = string.format(
      "%s -- called in function %s (%s:%d)",
      msg, function_name, source, line
    )

    -- Output the debug message
    if not schedule then
      vim.notify(dmsg, log_level)
    else
      vim.schedule(function()
        vim.notify(dmsg, log_level)
      end)
    end
  end
end


---Prints actual state for debugging to the console
function M.print_win_buf_state()
  print("State Buffers:", vim.inspect(require("reposcope.state.ui.ui_state").get_buffers()))
  print("State Windows:", vim.inspect(require("reposcope.state.ui.ui_state").get_windows()))
end

return M
