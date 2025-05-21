---@class UIPromptInput
---@brief Collects current input values from all active prompt fields and triggers a search.
---@description
--- This module retrieves all field input (from `prompt_state`), returns it as a structured
--- table, and optionally triggers a GitHub (or other) provider search when `on_enter()` is called.
---@field collect fun(): table<string, string>
---@field on_enter fun(): nil

local M = {}

-- Config
local config = require("reposcope.config")
-- State
local prompt_config = require("reposcope.ui.prompt.prompt_config")
local prompt_state = require("reposcope.state.ui.prompt_state")
-- Providers
local gh_repositories = require("reposcope.providers.github.repositories")
-- Utilities
local notify = require("reposcope.utils.debug").notify
local query_builder = require("reposcope.providers.github.query_builder")


---Collects input from each active prompt field
---@return table<string, string>
function M.collect()
  local result = {}

  for _, field in ipairs(prompt_config.fields or {}) do
    local text = prompt_state.get_field_text(field)
    if type(text) == "string" and text ~= "" then
      result[field] = text
    end
  end

  return result
end


---Handles <CR> key inside prompt – builds query and triggers provider
---@return nil
function M.on_enter()
  local input = M.collect()
  local query = query_builder.build(input)

  if query == "" then
    notify("[reposcope] No input to search", 2)
    return
  end

  if config.options.provider == "github" then
    gh_repositories.init(query)
  else
    notify("[reposcope] No valid provider configured in `options.provider`", 4)
  end
end

return M
