---@module 'reposcope.ui.sidebar.sidebar_window'
---@brief Narrow, read-only left sidebar showing the active filter, sort mode, and result count.
---@description
--- Purely informational — non-focusable, no keymaps of its own — so it adds
--- zero risk to the existing focus/keymap logic. `M.refresh()` is called from
--- `list_controller.display_repositories()`, the single place every real
--- list change (search, filter, sort, filter-clear) already funnels through,
--- so the sidebar never needs its own change-tracking.

---@class SidebarWindow : SidebarWindowModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_win_close = api.nvim_win_close
local nvim_open_win = api.nvim_open_win
-- Configuration
local config = require("reposcope.ui.sidebar.sidebar_config")
local ui_config = require("reposcope.ui.config")
-- State
local ui_state = require("reposcope.state.ui.ui_state")
-- Utilities
local notify = require("reposcope.utils.debug").notify
local create_named_buffer = require("reposcope.utils.protection").create_named_buffer

---@private
---@internal
---Builds the sidebar's display lines from current filter/sort/result state.
---@return string[]
local function build_lines()
  local filter_text = require("reposcope.ui.actions.filter_repos").get_current_filter()
  local sort_mode = require("reposcope.ui.actions.sort_prompt").get_current_sort()
  local total = require("reposcope.cache.repository_cache").get().total_count or 0

  return {
    "",
    " Filter",
    "  " .. (filter_text ~= "" and filter_text or "(none)"),
    "",
    " Sort",
    "  " .. sort_mode,
    "",
    " Results",
    "  " .. tostring(total),
  }
end

---Opens the sidebar window (idempotent — a no-op if already open).
---@return boolean
function M.open_window()
  if ui_state.buffers.sidebar and not nvim_buf_is_valid(ui_state.buffers.sidebar) then
    ui_state.buffers.sidebar = nil
  end
  if ui_state.windows.sidebar and not nvim_win_is_valid(ui_state.windows.sidebar) then
    ui_state.windows.sidebar = nil
  end

  if ui_state.buffers.sidebar then return true end

  local buf = create_named_buffer("reposcope://sidebar")
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Failed to create sidebar buffer.", 4)
    return false
  end

  ui_state.buffers.sidebar = buf
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"

  ui_state.windows.sidebar = nvim_open_win(buf, false, {
    relative = "editor",
    row = config.row,
    col = config.col,
    width = config.width,
    height = config.height,
    style = "minimal",
    border = config.border or "none",
    focusable = false,
    noautocmd = true,
  })

  local win = ui_state.windows.sidebar
  if win and nvim_win_is_valid(win) then
    vim.wo[win].wrap = false
    local ns = api.nvim_create_namespace("reposcope_sidebar")
    api.nvim_set_hl(ns, "Normal", { bg = ui_config.colortheme.background, fg = ui_config.colortheme.text })
    api.nvim_win_set_hl_ns(win, ns)
  end

  M.refresh()
  return true
end

---Refreshes the sidebar's content. Safe to call even if the sidebar isn't open.
---@return nil
function M.refresh()
  local buf = ui_state.buffers.sidebar
  if not buf or not nvim_buf_is_valid(buf) then return end

  local lines = build_lines()
  vim.bo[buf].modifiable = true
  api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

---Closes the sidebar window and buffer.
---@return nil
function M.close_window()
  if ui_state.windows.sidebar and nvim_win_is_valid(ui_state.windows.sidebar) then
    nvim_win_close(ui_state.windows.sidebar, true)
  end
  ui_state.windows.sidebar = nil
  ui_state.buffers.sidebar = nil
end

return M
