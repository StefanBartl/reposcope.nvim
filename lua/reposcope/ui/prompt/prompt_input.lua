---@module 'reposcope.ui.prompt.prompt_input'
---@brief Collects current input values from all active prompt fields and triggers a search.

---@class UIPromptInput : UIPromptInputModule
local M = {}

-- State
local get_fields = require("reposcope.ui.prompt.prompt_config").get_fields
local get_field_text = require("reposcope.state.ui.prompt_state").get_field_text
-- Providers
local provider_controller = require("reposcope.controllers.provider_controller")
local fetch_repositories_and_display = provider_controller.fetch_repositories_and_display
local build_query = provider_controller.build_query
-- Query frequency tracking (":Reposcope queries")
local record_query = require("reposcope.state.query_stats").record
-- Utilities
local notify = require("reposcope.utils.debug").notify

---Last search query string built by `on_enter` (empty if none yet)
---@type string
local _last_query = ""

---Collects input from each active prompt field
---@return table<string, string> result Keyed by prompt field, containing non-empty values
function M.collect()
  ---@type table<string, string>
  local result = {}

  local fields = get_fields() or {}
  local get = get_field_text

  for i = 1, #fields do
    local field = fields[i]
    local text = get(field)
    if type(text) == "string" and text ~= "" then result[field] = text end
  end

  return result
end

---Handles <CR> key inside prompt – builds query and triggers provider
---@return nil
function M.on_enter()
  local input = M.collect()
  local query = build_query(input)

  if query == "" then
    notify("[reposcope] No input to search", 2)
    return
  end

  _last_query = query
  record_query(query)
  fetch_repositories_and_display(query)
end

---Returns the last search query string built by `on_enter` ("" if none yet)
---@return string
function M.get_last_query() return _last_query end

return M
