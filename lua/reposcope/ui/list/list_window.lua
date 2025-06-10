---@module 'reposcope.ui.list.list_window'
---@brief Manages the list window for displaying repositories
---@description
---This module is responsible for creating, configuring, and managing the list window.
---It provides functions to open, close, and apply layout configurations to the list window.
---The list window displays the list of repositories which are prompted and highlights the selected entry.

---@class ListWindow : ListWindowModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_win_close = api.nvim_win_close
local nvim_open_win = api.nvim_open_win
local nvim_set_hl = vim.api.nvim_set_hl
local nvim_buf_get_lines = vim.api.nvim_buf_get_lines
local nvim_buf_clear_namespace = vim.api.nvim_buf_clear_namespace
local nvim_buf_set_extmark = vim.api.nvim_buf_set_extmark
local nvim_win_set_hl_ns = vim.api.nvim_win_set_hl_ns
-- Configuration and Layout
local config = require("reposcope.ui.list.list_config")
local ui_config = require("reposcope.ui.config")
local prompt_config = require("reposcope.ui.prompt.prompt_config")
-- State Management
local ui_state = require("reposcope.state.ui.ui_state")
-- Utility Modules
local notify = require("reposcope.utils.debug").notify
local create_named_buffer = require("reposcope.utils.protection").create_named_buffer


local HIGHLIGHT_NS = vim.api.nvim_create_namespace("reposcope.list")
M.highlighted_line = 1

-- List of available test layouts --- LAYOUTS!
M.Layouts = {
  Normal = {
    row = math.floor(ui_config.row + prompt_config.height + 1),
    col = math.floor(ui_config.col + 1),
    width = math.floor((ui_config.width / 2) - 1),
    height = math.floor(ui_config.height - prompt_config.height - 2),
  },
  Compact = {
    row = math.floor(ui_config.row + 1),
    col = math.floor(ui_config.col + 1),
    width = math.floor((ui_config.width / 2.5) - 1),
    height = math.floor(ui_config.height - prompt_config.height - 4),
  },
  Fullscreen = {
    row = 0,
    col = 0,
    width = math.floor(vim.o.columns),
    height = math.floor(vim.o.lines),
  }
}


---Opens list window, ensures the list window and buffer are created and initialized
---@return boolean True if the list window is ready, false otherwise
function M.open_window()
  -- Reset buffer and/or if invalid
  if ui_state.buffers.list and not nvim_buf_is_valid(ui_state.buffers.list) then
    ui_state.buffers.list = nil
  end
  if ui_state.windows.list and not nvim_win_is_valid(ui_state.windows.list) then
    ui_state.windows.list = nil
  end

  if not ui_state.buffers.list then
    local buf = create_named_buffer("reposcope://list")
    if not buf or not nvim_buf_is_valid(buf) then
      notify("[reposcope] Failed to create list buffer.", 4)
      return false
    end

    ui_state.buffers.list = buf
    vim.bo[ui_state.buffers.list].buftype = "nofile"
    vim.bo[ui_state.buffers.list].modifiable = false
    vim.bo[ui_state.buffers.list].bufhidden = "wipe"

    ui_state.windows.list = nvim_open_win(buf, false, { -- NOTE: LAYOUTS!
      relative = "editor",
      row = M.Layouts.Normal.row,
      col = M.Layouts.Normal.col,
      width = M.Layouts.Normal.width,
      height = M.Layouts.Normal.height,
      style = "minimal",
      border = config.border or "none",
      focusable = true,
      noautocmd = true,
    })

    M.apply_layout()
    return true
  else
    return true
  end
end

---Closes the list window
---@return nil
function M.close_window()
  if ui_state.windows.list and nvim_win_is_valid(ui_state.windows.list) then
    nvim_win_close(ui_state.windows.list, true)
  end
  ui_state.windows.list = nil
  ui_state.buffers.list = nil
end

---Configures the list buffer with UI settings (no editing, restricted keymaps).
---@return nil
function M.configure()
  local buf = ui_state.buffers.list
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] List buffer configure failed", 4)
    return
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].swapfile = false

  notify("[reposcope] List buffer configured.", 2)
end

---Applies the layout and styling to the list window
---@return nil
function M.apply_layout()
  local win = ui_state.windows.list
  if not win or not nvim_win_is_valid(win) then
    notify("[reposcope] List window is not open or not valid", 3)
    return
  end

  local ns = vim.api.nvim_create_namespace("reposcope_list")

  nvim_set_hl(ns, "ReposcopeListSelected", {
    bg = config.highlight_color,
    fg = config.normal_color,
    bold = true,
  })

  nvim_win_set_hl_ns(win, ns)

  if win and nvim_win_is_valid(win) then
    vim.wo[win].wrap = false
    vim.wo[win].scrolloff = 3
  end


  nvim_set_hl(ns, "Normal", {
    bg = ui_config.colortheme.background,
    fg = ui_config.colortheme.text,
  })
end

---Highlights the selected list entry at the specified index
---@param index number The index of the entry to highlight
---@return nil
function M.highlight_selected(index)
  local buf = ui_state.buffers.list
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] List buffer not available for highlighting.", 3)
    return
  end

  if type(index) ~= "number" then
    notify("[reposcope] Invalid index for highlighting.", 4)
    return
  end

  local lines = nvim_buf_get_lines(buf, 0, -1, false)
  if #lines == 0 then
    notify("[reposcope] List is empty, cannot highlight.", 3)
    return
  end

  if index < 1 or index > #lines then
    notify("[reposcope] Index out of range for highlighting.", 4)
    return
  end

  -- Clear previous highlights
  nvim_buf_clear_namespace(buf, HIGHLIGHT_NS, 0, -1)

  local line = nvim_buf_get_lines(buf, index - 1, index, false)[1] or ""
  -- Apply persistent highlight using extmark
  nvim_buf_set_extmark(buf, HIGHLIGHT_NS, index - 1, 0, {
    end_row = index - 1,
    end_col = #line,
    hl_group = "ReposcopeListSelected"
  })

  M.highlighted_line = index
end

---Sets the highlighted line in the list UI.
---@param line number The line number to highlight
---@return nil
function M.set_highlighted_line(line)
  local buf = ui_state.buffers.list
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] List buffer not found.", 4)
    return
  end

  if type(line) ~= "number" then
    notify("[reposcope] Invalid line for highlighting.", 4)
    return
  end

  nvim_buf_clear_namespace(buf, HIGHLIGHT_NS, 0, -1)

  nvim_buf_set_extmark(buf, HIGHLIGHT_NS, line - 1, 0, {
    end_row = line - 1,
    end_col = -1,
    hl_group = "ReposcopeListSelected"
  })

  M.highlighted_line = line
end

---Returns the currently highlighted list entry
---@return string|nil The text of the highlighted list entry
function M.get_highlighted_entry()
  if not ui_state.buffers.list or not nvim_buf_is_valid(ui_state.buffers.list) then
    notify("[reposcope] List buffer not available.", 3)
    return nil
  end

  local lines = nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)
  if #lines == 0 then
    return nil
  end

  return lines[M.highlighted_line] or nil
end

return M
