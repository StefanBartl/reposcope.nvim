---@module 'reposcope.ui.prompt.prompt_focus'
---@brief Manages cursor focus and navigation logic within the prompt input UI.
---@description
--- This module handles initial focus assignment and field navigation inside
--- the prompt UI.

---@class UIPromptFocus : UIPromptFocusModule
local M = {}
-- Vim Utilities
local api = vim.api
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_set_current_win = api.nvim_set_current_win
local nvim_win_set_cursor = vim.api.nvim_win_set_cursor
local nvim_win_get_config = vim.api.nvim_win_get_config
-- UI State
local ui_state = require("reposcope.state.ui.ui_state")
-- Prompt config
local get_fields = require("reposcope.ui.prompt.prompt_config").get_fields
-- Utilities
local notify = require("reposcope.utils.debug").notify


-- Internal tracking
local current_index = 1


---Sets the current prompt navigation index
---@param index integer
function M.set_current_index(index)
  current_index = index
end

---Focuses the first focusable prompt input window (skips prefix).
---@return nil
function M.focus_first_input()
  local fields = get_fields()
  local wins = ui_state.windows.prompt or {}

  for i = 1, #fields do
    local field = fields[i]
    local win = wins[field]

    if type(win) == "number" and nvim_win_is_valid(win) then
      local config = nvim_win_get_config(win)
      if config.focusable then
        nvim_set_current_win(win)
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
  local fields = get_fields()
  local field = fields[index]
  if not field then return end

  local win = ui_state.windows.prompt and ui_state.windows.prompt[field]
  if not win or not nvim_win_is_valid(win) then
    notify("[reposcope] Invalid window for field: " .. tostring(field), 3)
    return
  end

  local cfg = nvim_win_get_config(win)
  if not cfg.focusable then
    notify("[reposcope] Attempted to focus non-focusable window: " .. field, 3)
    return
  end

  current_index = index
  nvim_set_current_win(win)
  nvim_win_set_cursor(win, { 2, 0 })
end

---Focuses a prompt field by its name, only if it is focusable
---@param field string Field name to focus (e.g. "keywords")
---@return nil
function M.focus_field(field)
  local fields = get_fields()
  local wins = ui_state.windows.prompt or {}

  for i = 1, #fields do
    if fields[i] == field then
      local win = wins[field]
      if type(win) == "number" and nvim_win_is_valid(win) then
        local cfg = nvim_win_get_config(win)
        if cfg.focusable then
          M.focus_field_index(i)
        end
      end
      break -- no need to keep searching after match
    end
  end
end

---Navigates to the next or previous prompt field, skipping non-focusable ones (e.g. prefix)
---@param direction "next"|"prev"
---@return nil
function M.navigate(direction)
  local fields = get_fields()
  local count = #fields
  local step = direction == "next" and 1 or -1
  local idx = current_index

  -- Try up to `count` times to find the next focusable field
  -- Prevents infinite loops if no valid window is focusable
  for _ = 1, count do
    -- Move to the next index (with wrap-around behavior)
    idx = idx + step
    if idx < 1 then
      idx = count
    elseif idx > count then
      idx = 1
    end

    -- Resolve field name and associated window
    local field = fields[idx]
    local win = ui_state.windows.prompt and ui_state.windows.prompt[field]

    if win and nvim_win_is_valid(win) then
      local cfg = nvim_win_get_config(win)

      -- Skip windows that are not focusable (e.g. prefix)
      if cfg.focusable then
        -- Focus this window and update current index
        return M.focus_field_index(idx)
      end
    end
  end

  -- Fallback
  notify("[reposcope] No focusable prompt field found", 3)
  M.focus_field_index(1)
end

return M
