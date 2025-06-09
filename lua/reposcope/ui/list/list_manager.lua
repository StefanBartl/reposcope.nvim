---@module 'reposcope.ui.list.list_manager'
---@brief Manages the content and state of the list window
---@description
---This module is responsible for handling the list content (repositories) and their display.
---It provides functions to load, update, and clear the list, and to manage the selected line.
---The list manager is independent of the UI and can be used with any list window.

---@class ListManager : ListManagerModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_set_lines = api.nvim_buf_set_lines
local nvim_win_get_cursor = vim.api.nvim_win_get_cursor
local nvim_buf_get_lines = vim.api.nvim_buf_get_lines
-- UI Components
local open_window = require("reposcope.ui.list.list_window").open_window
local close_window = require("reposcope.ui.list.list_window").close_window
local highlight_selected = require("reposcope.ui.list.list_window").highlight_selected
local inject_content = require("reposcope.ui.preview.preview_manager").inject_content
-- State Management
local ui_state = require("reposcope.state.ui.ui_state")
-- Debugging and Utilities
local notify = require("reposcope.utils.debug").notify
local center_text = require("reposcope.utils.text").center_text

-- Prepare message for empty table preview window
local preview_width = require("reposcope.ui.preview.preview_config").width
local empty_tbl_msg = center_text("No results. Try a different keyword or remove filters.", preview_width)


---Sets the list entries and displays them in the list window
---@param entries string[] The list of entries to display
---@return nil
function M.set_and_display_list(entries)
  if not entries then
    notify("[reposcope] 'entries'-table is missed", 4)
    return
  end

  open_window()

  if M.update_list(entries) then
    ui_state.set_list_populated(true)
  else
    ui_state.set_list_populated(false)
  end
end

---Updates the list content with the provided lines and returns status
---@nodiscard
---@param lines string[] The list of repository entries to display
---@return boolean
function M.update_list(lines)
  if not lines or type(lines) ~= "table" then
    notify("[reposcope] 'lines'-argument is missed or has invalid type (table needed)", 4)
    return false
  end

  if vim.tbl_isempty(lines) then
    notify("[reposcope] No repositories found for this query.", 3)
    inject_content(ui_state.buffers.preview, empty_tbl_msg, "text")
    M.clear_list()
    return false
  end

  if type(lines[1]) ~= "string" then
    notify("[reposcope] 'lines'-table must consist of string(s)", 4)
    notify("[reposcope] lines type: " .. type(lines[1]), 4)
    return false
  end

  local buf = ui_state.buffers.list

  if not buf then
    notify("[reposcope] List buffer is not available.", 3)
    return false
  end

  vim.schedule(function()
    vim.bo[buf].modifiable = true
    nvim_buf_set_lines(buf, 0, -1, false, lines)
    vim.bo[buf].modifiable = false

    highlight_selected(ui_state.list.last_selected_line or 1)

    -- Update preview if possible   REF:  these imports maybe at filescope ?
    local selected_repo = require("reposcope.cache.repository_cache").get_selected()
    if selected_repo and selected_repo.name and selected_repo.owner and selected_repo.owner.login then
      vim.schedule(function()
        require("reposcope.ui.preview.preview_manager").update_preview(selected_repo.owner.login, selected_repo.name)
      end)
    else
      notify("[reposcope] No selected repository for preview.", 3)
    end
  end)

  return true
end

---Clears the list content and closes the list window
---@return nil
function M.clear_list()
  close_window()
  ui_state.set_list_populated(false)
end

---Returns the currently selected list entry
---@return string|nil The selected list entry text
function M.get_selected()
  if not ui_state.buffers.list then
    notify("[reposcope] List buffer not available.", 3)
    return nil
  end

  local cursor_pos = nvim_win_get_cursor(ui_state.windows.list)
  local line = cursor_pos[1]
  local lines = nvim_buf_get_lines(ui_state.buffers.list, line - 1, line, false)

  if #lines == 0 then
    notify("[reposcope] No line found at the cursor position.", 3)
    return nil
  end

  return lines[1]
end

---Selects a specific list entry (highlights it)
---@param index number The index of the entry to select
---@return nil
function M.select_entry(index)
  if type(index) ~= "number" then
    notify("[reposcope] Invalid index for selection.", 4)
    return
  end

  highlight_selected(index)
  notify("[reposcope] List entry selected at index: " .. index, 2)
end

---Resets the last selected line and the line highlight
---@return nil
function M.reset_selected_line()
  ui_state.list.last_selected_line = 1
  highlight_selected(1)
end

return M
