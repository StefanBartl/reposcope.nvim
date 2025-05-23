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
---@field select_entry fun(index: number): nil Selects a specific list entry  --REF: niuy
---@field get_selected_entry fun(): string|nil Returns the currently selected list entry  --REF: niuy
---@field reset_selected_line fun(): nil Resets the last selected line and the line highlight
local M = {}

-- UI Components (List Window)
local list_window = require("reposcope.ui.list.list_window")
-- State Management (UI State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Sets the list entries and displays them in the list window  REF:  update_and_open()
---@param entries string[] The list of entries to display
---@return nil
function M.set_list(entries)
  if not entries then
    notify("[reposcope] 'entries'-table is missed", 4)
    return
  end

  list_window.open_window()
  M.update_list(entries)
  ui_state.set_list_populated(true)
end


---Updates the list content with the provided lines
---@param lines string[] The list of repository entries to display
---@return nil
function M.update_list(lines)
  if not lines or type(lines) ~= "table" then
    notify("[reposcope] 'lines'-argument is missed or has invalid type (table needed)", 4)
    return
  end

  if type(lines[1]) ~= "string" then
    notify("[reposcope] 'lines'-table must consist of string(s)", 4)
    return
  end

  if not ui_state.buffers.list then
    notify("[reposcope] List buffer is not available.", 3)
    return
  end

  vim.schedule(function()
    vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", true)
    vim.api.nvim_buf_set_lines(ui_state.buffers.list, 0, -1, false, lines)
    vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", false)

    list_window.highlight_selected(ui_state.last_selected_line or 1)

    -- Update preview if possible
    local selected_repo = require("reposcope.state.repositories.repositories_state").get_selected_repo()
    if selected_repo then
      require("reposcope.ui.preview.preview_manager").update_preview(selected_repo.name)
    else
      notify("[reposcope] No selected repository for preview.", 3)
    end
  end)
end


---Clears the list content and closes the list window
---@return nil
function M.clear_list()
  list_window.close_window()
  ui_state.set_list_populated(false)
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


---Displays the list with the given entries
---@param entries string[] The list of repository entries to display
---@return nil
function M.show_list(entries)
  if type(entries) ~= "table" then
    notify("[reposcope] Invalid list entries (not a table).", 4)
    return
  end

  M.set_list(entries)
  notify("[reposcope] List UI displayed.", 2)
end


---Selects a specific list entry (highlights it)
---@param index number The index of the entry to select
---@return nil
function M.select_entry(index)
  if type(index) ~= "number" then
    notify("[reposcope] Invalid index for selection.", 4)
    return
  end

  list_window.highlight_selected(index)
  notify("[reposcope] List entry selected at index: " .. index, 2)
end


---Resets the last selected line and the line highlight
---@return nil
function M.reset_selected_line()
    ui_state.last_selected_line = 1
    list_window.highlight_selected(1)
end

return M
