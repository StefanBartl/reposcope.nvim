---@module 'reposcope.state.ui.prompt_state'
---@brief Tracks current field values entered in the prompt UI
---@description
--- This module maintains the current input state for each prompt field.
--- It allows reading and writing of field values, useful for preserving
--- user input across redraws or delayed operations.

---@class PromptStateManager : PromptStateManagerModule
local M = {}

--- Stores current text input for each prompt field
---@type table<string, string>
M.input = {}


--- Sets the current input text for a given prompt field
---@param field string The field key (e.g. "keywords", "owner")
---@param text string The user-entered value
---@return nil
function M.set_field_text(field, text)
  if type(field) == "string" and type(text) == "string" then
    M.input[field] = text
  end
end


--- Retrieves the input text for a given prompt field
---@param field string The field key
---@return string The current value (or empty string if unset)
function M.get_field_text(field)
  return M.input[field] or ""
end

return M
