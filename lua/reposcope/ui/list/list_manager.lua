---@class ListManager
---@brief Manages the content and state of the list window
---@description
---This module is responsible for handling the list content (repositories) and their display.
---It provides functions to load, update, and clear the list, and to manage the selected line.
---The list manager is independent of the UI and can be used with any list window.
---@field set_list fun(entries: string[]): nil Sets the list entries and displays them
---@field update_list fun(lines: string[]): nil Updates the list content
---@field clear_list fun(): nil Clears the list content
---@field get_selected fun(): string|nil Returns the currently selected list entry  --REF: niuy
local M = {}

local list_window = require("reposcope.ui.list.list_window")
local ui_state = require("reposcope.state.ui.ui_state")
local notify = require("reposcope.utils.debug").notify

---Sets the list entries and displays them in the list window
---@param entries string[] The list of entries to display
---@return nil
function M.set_list(entries)
  if type(entries) ~= "table" then
    notify("[reposcope] Invalid list entries (not a table).", 4)
    return
  end

  if #entries == 0 then
    notify("[reposcope] No entries to display in the list.", 3)
    M.clear_list()
    return
  end

  list_window.open_window()
  M.update_list(entries)
  ui_state.list_populated = true
end

---Updates the list content with the provided lines
---@param lines string[] The list of repository entries to display
---@return nil
function M.update_list(lines)
  if not ui_state.buffers.list then
    notify("[reposcope] List buffer is not available.", 3)
    return
  end
  vim.schedule(function()
    vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", true)
    vim.api.nvim_buf_set_lines(ui_state.buffers.list, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", false)
  end)
end

---Clears the list content and closes the list window
---@return nil
function M.clear_list()
  list_window.close_window()
  ui_state.list_populated = nil
end


---Returns the currently selected list entry
---@return string|nil The selected list entry text
function M.get_selected()
  if not ui_state.buffers.list then
    notify("[reposcope] List buffer not available.", 3)
    return nil
  end

  local cursor_pos = vim.api.nvim_win_get_cursor(ui_state.windows.list)
  local line = cursor_pos[1]
  local lines = vim.api.nvim_buf_get_lines(ui_state.buffers.list, line - 1, line, false)

  if #lines == 0 then
    notify("[reposcope] No line found at the cursor position.", 3)
    return nil
  end

  return lines[1]
end

return M
