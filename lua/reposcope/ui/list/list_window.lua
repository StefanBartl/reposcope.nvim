---@class ListWindow
---@brief Manages the list window for displaying repositories
---@description
---This module is responsible for creating, configuring, and managing the list window.
---It provides functions to open, close, and apply layout configurations to the list window.
---The list window displays the list of repositories which are prompted and highlights the selected entry.
---@field highlighted_line number Highlighted line index
---@field open_window fun(): boolean Opens list window, ensures the list window and buffer are created and initialized
---@field close_window fun(): nil Closes the list window
---@field configure fun(): nil Configures the list buffer with UI settings (no editing, restricted keymaps)
---@field apply_layout fun(): nil Applies layout and styling to the list window
---@field highlight_selected fun(index: number): nil Highlights the selected list entry
---@field set_highlighted_line fun(line: number): nil Sets the highlighted line in the list UI  --REF: niuy
---@field get_highlighted_entry fun(): string|nil Returns the currently highlighted list entry  --REF: niuy
local M = {}

local config = require("reposcope.ui.list.list_config")
local ui_config = require("reposcope.ui.config")
local prompt_config = require("reposcope.ui.prompt.config")
local ui_state = require("reposcope.state.ui.ui_state")
local notify = require("reposcope.utils.debug").notify
local protection = require("reposcope.utils.protection")

-- Highlighted line index
M.highlighted_line = 1

-- List of available test layouts --- TEST: 
M.Layouts = {
  Normal = {
    row = ui_config.row + prompt_config.height + 1,
    col = ui_config.col + 1,
    width = (ui_config.width / 2) - 1,
    height = ui_config.height - prompt_config.height - 2,
  },
  Compact = {
    row = ui_config.row + 1,
    col = ui_config.col + 1,
    width = (ui_config.width / 2.5) - 1,
    height = ui_config.height - prompt_config.height - 4,
  },
  Fullscreen = {
    row = 0,
    col = 0,
    width = vim.o.columns,
    height = vim.o.lines,
  }
}

---Opens list window, ensures the list window and buffer are created and initialized
---@return boolean True if the list window is ready, false otherwise
function M.open_window()
  if ui_state.buffers.list and vim.api.nvim_buf_is_valid(ui_state.buffers.list) then
    return true
  end

  local buf = protection.create_named_buffer("reposcope://list")
  if not buf then
    notify("[reposcope] Failed to create list buffer.", 4)
    return false
  end

  ui_state.buffers.list = buf
  ui_state.windows.list = vim.api.nvim_open_win(buf, false, {  --TEST:  layouts...
    relative = "editor",
    row = M.Layouts.Normal.row,
    col = M.Layouts.Normal.col,
    width = M.Layouts.Normal.width,
    height = M.Layouts.Normal.height,
    style = "minimal",
    border = config.border or "none",
    focusable = false,
    noautocmd = true,
  })

  M.apply_layout()
  notify("[reposcope] List buffer and window initialized.", 2)
  return true
end
--title = "Repositories", -- NOTE: Try
--title_pos = "left",     -- NOTE: Try

---Closes the list window
---@return nil
function M.close_window()
  if ui_state.windows.list and vim.api.nvim_win_is_valid(ui_state.windows.list) then
    vim.api.nvim_win_close(ui_state.windows.list, true)
  end
  ui_state.windows.list = nil
  ui_state.buffers.list = nil
end

---Configures the list buffer with UI settings (no editing, restricted keymaps).
---@return nil
function M.configure()
  local buf = ui_state.buffers.list
  if not buf then
    vim.schedule(function()
      notify("[reposcope] List configure failed", 4)
    end)
    return
  end

  vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
  vim.api.nvim_buf_set_option(buf, "swapfile", false)

  -- REF: needed? not focusable?

  -- Restricted keymaps in the list buffer
  --local keys = { "h", "j", "k", "l", "i", "a", "o", "v", "<Up>", "<Down>" }
  --for _, key in ipairs(keys) do
  --  vim.api.nvim_buf_set_keymap(buf, "n", key, "<Nop>", { silent = true, noremap = true })
  --end

  notify("[reposcope] List buffer configured.", 2)
end

---Applies the layout and styling to the list window
---@return nil
function M.apply_layout()
  if not ui_state.windows.list then
    notify("[reposcope] List window is not open.", 3)
    return
  end

  local ns = vim.api.nvim_create_namespace("reposcope_list")

  vim.api.nvim_set_hl(ns, "ReposcopeListSelected", {
    bg = config.highlight_color,
    fg = config.normal_color,
    bold = true,
  })

  vim.api.nvim_win_set_hl_ns(ui_state.windows.list, ns)

  vim.api.nvim_win_set_option(ui_state.windows.list, "wrap", false)
  vim.api.nvim_win_set_option(ui_state.windows.list, "scrolloff", 3)

  vim.api.nvim_set_hl(ns, "Normal", {
    bg = ui_config.colortheme.background,
    fg = ui_config.colortheme.text,
  })

  notify("[reposcope] List layout and styling applied.", 2)
end


---Highlights the selected list entry at the specified index
---@param index number The index of the entry to highlight
---@return nil
function M.highlight_selected(index)
  if not ui_state.buffers.list then
    notify("[reposcope] List buffer not available for highlighting.", 3)
    return
  end

  if type(index) ~= "number" then
    notify("[reposcope] Invalid index for highlighting.", 4)
    return
  end

  local lines = vim.api.nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)
  if #lines == 0 then
    notify("[reposcope] List is empty, cannot highlight.", 3)
    return
  end

  if index < 1 or index > #lines then
    notify("[reposcope] Index out of range for highlighting.", 4)
    return
  end

  -- Clear all highlights first
  vim.api.nvim_buf_clear_namespace(ui_state.buffers.list, -1, 0, -1)

  -- Highlight the selected line
  vim.api.nvim_buf_add_highlight(
    ui_state.buffers.list,
    -1,
    "ReposcopeListSelected",
    index - 1,
    0,
    -1
  )

  -- Store highlighted line index
  M.highlighted_line = index
end

---Sets the highlighted line in the list UI.
---@param line number The line number to highlight
function M.set_highlighted_line(line)
  if not ui_state.buffers.list then
    notify("[reposcope] List buffer not found.", 4)
    return
  end

  if type(line) ~= "number" then
    notify("[reposcope] Invalid line for highlighting.", 4)
    return
  end

  -- Clear all highlights first
  vim.api.nvim_buf_clear_namespace(ui_state.buffers.list, -1, 0, -1)

  -- Highlight the specified line
  vim.api.nvim_buf_add_highlight(
    ui_state.buffers.list,
    -1,
    "ReposcopeListSelected",
    line - 1,
    0,
    -1
  )

  M. highlighted_line = line
end

---Returns the currently highlighted list entry
---@return string|nil The text of the highlighted list entry
function M.get_highlighted_entry()
  if not ui_state.buffers.list then
    notify("[reposcope] List buffer not available.", 3)
    return nil
  end

  local lines = vim.api.nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)
  if #lines == 0 then
    return nil
  end

  return lines[M.highlighted_line] or nil
end


return M
