---@class ReposcopeDebug Debug utilities for inspecting UI-related buffers and windows.
---@field notify fun(message: string, level?: number): nil Sends a notification message with an optional log level.
---@field test_prompt_input fun(provider: string, query: string) Manually test the input router, either "github" or other (for fallback)
local M = {}

local config = require("reposcope.config")

---Sends a notification message with an optional log level.
---@param message string The notification message
---@param level? number Optional vim.log.levels (default: INFO)
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  if config.is_dev_mode() or level >= vim.log.levels.WARN then
    vim.notify(message, level)
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
