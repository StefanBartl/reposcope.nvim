---@class ReposcopeDebug Debug utilities for inspecting UI-related buffers and windows.
---@field options DebugOptions Configurations options for debugging of reposcope
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
---@field test_prompt_input fun(provider: string, query: string) Manually test the input router, either "github" or other (for fallback)
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

---Manually test the input router with a specified provider and query.
---@param provider string The provider to test (e.g., "github")
---@param query string The search query for the provider
function M.test_prompt_input(provider, query)
  require("reposcope.config").options.provider = provider
  print(string.format("[test] Using provider: %s", provider))
  require("reposcope.ui.prompt.input").on_enter(query)
end

return M
