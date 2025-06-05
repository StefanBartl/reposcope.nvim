---@module 'reposcope.ui.prompt.prompt_config'
---@brief Static configuration values for the prompt input layout
---@description
--- This module defines the configuration used to render the prompt input UI,
--- including visual layout constants and the active prompt fields. Field access is
--- managed through `set_fields()` and `get_fields()` to ensure normalization,
--- deduplication and ordering. This ensures correct window generation and layout.

---@class UIPromptConfig : UIPromptConfigModule
local M = {}

-- UI Config
local ui_config = require("reposcope.ui.config")
-- Utilities
local dedupe_list = require("reposcope.utils.core").dedupe_list
local put_to_front_if_present = require("reposcope.utils.core").put_to_front_if_present
local notify = require("reposcope.utils.debug").notify


-- Static layout values
M.row = ui_config.row
M.col = ui_config.col
M.width = math.floor(ui_config.width / 2)
M.height = 3

-- Prefix
M.prefix = " " .. "\u{f002}" .. " "
M.prefix_len = vim.fn.strdisplaywidth(M.prefix)
M.prefix_win_width = M.prefix_len + 2

---@class PromptFieldClass
---@brief Enumeration of valid prompt field keys
---@description
--- This class defines the allowed field names for prompt input configuration.
--- It is used for validation, autocomplete suggestions, and type safety.

---@type table<PromptField, boolean>
local VALID_FIELDS = {
  prefix = true,
  keywords = true,
  owner = true,
  topic = true,
  language = true,
  stars = true,
}

-- Internal storage for prompt fields (controlled by set_fields)
---@type PromptField[]
local _fields = {}

---Sets the active prompt fields with deduplication and prefix reordering.
---Invalid fields are ignored with a warning.
---@param fields PromptField[] List of valid field names
---@return nil
function M.set_fields(fields)
  if type(fields) ~= "table" then
    notify("[reposcope] Expected table for prompt fields, got: " .. type(fields), 3)
    return
  end

  local filtered = {}
  local valid = VALID_FIELDS
  local notify_invalid = notify

  -- Filter only valid fields
  for i = 1, #fields do
    local field = fields[i]
    if valid[field] then
      filtered[#filtered + 1] = field
    else
      notify_invalid("[reposcope] Ignored invalid field: " .. tostring(field), 2)
    end
  end

  -- Remove duplicates and ensure 'prefix' is front if present
  local deduped = dedupe_list(filtered)
  _fields = put_to_front_if_present(deduped, "prefix")
end

--- Returns the normalized prompt field list
---@return PromptField[]
function M.get_fields()
  return _fields
end

---Returns all valid prompt field names (whitelist)
---@return string[]
function M.get_available_fields()
  local result = {}
  for field, _ in pairs(VALID_FIELDS) do
    table.insert(result, field)
  end
  table.sort(result) -- optional alphabetisch
  return result
end

return M
