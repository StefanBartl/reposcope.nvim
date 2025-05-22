---@class UIPromptFocus
---@brief Manages cursor focus and navigation logic within the prompt input UI.
---@description
--- This module handles initial focus assignment and field navigation inside
--- the prompt UI. It allows jumping between fields (e.g. via <C-j>/<C-k>),
--- forces the cursor to line 2, and skips non-focusable fields like "prefix".
--- The field order is derived from `prompt_config.get_fields()`.
---
---@field focus_first_input fun(): nil Sets focus to the first interactive prompt input field and enters insert mode.
---@field focus_field_index fun(index: integer): nil Sets focus to the input field at the specified index (1-based), and positions the cursor at line 2.
---@field focus_field fun(field: string): nil Focuses a field by its name (e.g. "keywords") if it exists in the configured field list --NOTE: nuiy
---@field navigate_field fun(direction: "next"|"prev"): nil Navigates to the next or previous field in the list, wrapping around  --NOTE: niuy
local M = {}

-- UI State
local ui_state = require("reposcope.state.ui.ui_state")
-- Prompt config
local prompt_config = require("reposcope.ui.prompt.prompt_config")
-- Utilities
local notify = require("reposcope.utils.debug").notify


-- Internal tracking
local current_index = 1


--- Focuses the first focusable prompt input window (skips prefix).
---@return nil
function M.focus_first_input()
  local fields = prompt_config.get_fields()
  for _, field in ipairs(fields) do
    local win = ui_state.windows.prompt and ui_state.windows.prompt[field]
    if win and vim.api.nvim_win_is_valid(win) then
      local config = vim.api.nvim_win_get_config(win)
      if config.focusable then
        vim.api.nvim_set_current_win(win)
        vim.cmd("startinsert")
        return
      end
    end
  end
end


---Focuses the prompt field at the given index
---@param index integer
---@return nil
function M.focus_field_index(index)
  local fields = prompt_config.get_fields()
  local field = fields[index]
  if not field then return end

  local win = ui_state.windows.prompt and ui_state.windows.prompt[field]
  if not win or not vim.api.nvim_win_is_valid(win) then
    notify("[reposcope] Invalid window for field: " .. tostring(field), 3)
    return
  end

  current_index = index
  vim.api.nvim_set_current_win(win)
  vim.api.nvim_win_set_cursor(win, { 2, 0 }) -- Always line 2
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
function M.navigate_field(direction)
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
