---@class UIPromptNavigation
---@brief Enables cursor navigation between prompt input fields using keybindings.
---@description
--- This module allows the user to navigate between multiple prompt input fields
--- using keybindings like `<C-j>` (down/next) and `<C-k>` (up/prev). It respects
--- the order defined in `prompt_config.fields` and ensures the cursor stays in line 2.
---@field focus_field_index fun(index: integer): nil Focuses the prompt field at the given index
---@field focus_field fun(field: string): nil Forces focus to the given field
---@field navigate fun(direction: "next"|"prev"): nil Moves focus to the next or previous field

local M = {}

-- System
local api = vim.api
-- Config
local prompt_config = require("reposcope.ui.prompt.prompt_config")
-- State
local ui_state = require("reposcope.state.ui.ui_state")
-- Utilities
local notify = require("reposcope.utils.debug").notify


-- Internal tracking
local current_index = 1


---Focuses the prompt field at the given index
---@param index integer
---@return nil
function M.focus_field_index(index)
  local fields = prompt_config.get_fields()
  local field = fields[index]
  if not field then return end

  local win = ui_state.windows.prompt and ui_state.windows.prompt[field]
  if not win or not api.nvim_win_is_valid(win) then
    notify("[prompt_navigate] Invalid window for field: " .. tostring(field), 3)
    return
  end

  current_index = index
  api.nvim_set_current_win(win)
  api.nvim_win_set_cursor(win, { 2, 0 }) -- Always line 2
end


---Focuses a field by its name
---@param field string
---@return nil
function M.focus_field(field)
  local fields = prompt_config.get_fields()
  for i, name in ipairs(fields) do
    if name == field then
      return M.focus_field_index(i)
    end
  end
end


---Navigates to the next or previous prompt field
---@param direction "next"|"prev"
---@return nil
function M.navigate(direction)
  local delta = direction == "next" and 1 or -1
  local fields = prompt_config.get_fields()
  local new_index = current_index + delta

  if new_index < 1 then
    new_index = #fields
  elseif new_index > #fields then
    new_index = 1
  end

  M.focus_field_index(new_index)
end

return M
