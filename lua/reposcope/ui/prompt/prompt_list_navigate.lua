---@module 'reposcope.ui.prompt.prompt_list_navigate'
---@brief Allows prompt-driven list navigation within the Reposcope UI.
---@description
--- This module provides functions to allow user interaction with the repository list UI
--- while remaining in the prompt input buffer.

---@class UIPromptNavigation : UIPromptNavigationModule
local M = {}
local nvim_buf_get_lines = vim.api.nvim_buf_get_lines

-- UI Components (List Window)
local list_window = require("reposcope.ui.list.list_window")
local highlight_selected = require("reposcope.ui.list.list_window").highlight_selected
-- State Management (UI State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Allows navigation within the list directly from the prompt
---@param direction "up"|"down" The direction to navigate ("up" or "down")
---@return nil
function M.navigate_list_in_prompt(direction)
  local total_lines = #nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)
  if total_lines == 0 then return end

  -- Default to first line if not set
  list_window.highlighted_line = list_window.highlighted_line or 1

  -- Adjust current highlighted line
  if direction == "up" then
    list_window.highlighted_line = math.max(list_window.highlighted_line - 1, 1)
  elseif direction == "down" then
    list_window.highlighted_line = math.min(list_window.highlighted_line + 1, total_lines)
  end

  highlight_selected(list_window.highlighted_line)
end


---Sets the list's current line to given line number
---@param line string
---@return nil
function M.set_list_to(line)
  if type(line) ~= "number" then
    notify("[reposcope] Type 'number' is required for argument line, passed " .. type(line), 1)
    return
  end

  local total_lines = #nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)

  if line < 1 or line > total_lines then
    notify("[reposcope] Invalid line value: " .. line, 1)
    return
  end

  list_window.highlighted_line = line
  highlight_selected(line)
end

return M
