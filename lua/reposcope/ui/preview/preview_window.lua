---@module 'reposcope.ui.preview.preview_window'
---@brief Manages the preview window for displaying repository README content.
---@description
---The `PreviewWindow` module is responsible for creating and configuring the preview window.
---It handles the layout, visual styling, and content injection from cached or live README sources.
---This window is typically opened alongside the list and prompt components and is non-focusable.

---@class PreviewWindow : PreviewWindowModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_win_close = api.nvim_win_close
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_open_win = api.nvim_open_win
local nvim_set_hl = vim.api.nvim_set_hl
local nvim_create_namespace = vim.api.nvim_create_namespace
local nvim_win_set_hl_ns = vim.api.nvim_win_set_hl_ns
-- Configuration (Global and UI-Specific)
local preview_config = require("reposcope.ui.preview.preview_config")
-- State Management (UI State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Protection and Error Handling
local create_named_buffer = require("reposcope.utils.protection").create_named_buffer
local notify = require("reposcope.utils.debug").notify


---Opens the preview window and injects the initial banner
---@return boolean
function M.open_window()
  local buf = ui_state.buffers.preview

  -- Reset buffer if invalid
  if buf and not nvim_buf_is_valid(buf) then
    buf = nil
  end

  if not buf or not nvim_buf_is_valid(buf) then
    buf = create_named_buffer("reposcope://preview")
    if not buf or not nvim_buf_is_valid(buf) then
      notify("[reposcope] Preview buffer cannot be created.", 4)
      return false
    end

    ui_state.buffers.preview = buf

    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modifiable = true
    vim.bo[buf].bufhidden = "wipe"

    local win = nvim_open_win(buf, false, {
      relative = "editor",
      row = preview_config.row,
      col = preview_config.col,
      width = preview_config.width,
      height = preview_config.height,
      style = "minimal",
      border = preview_config.border or "none",
      focusable = false,
      noautocmd = true,
    })

    ui_state.windows.preview = win

    M.apply_layout()
    return true
  else
    return true
  end
end


---Closes the preview window
---@return nil
function M.close_window()
  local win = ui_state.windows.preview

  if win and nvim_win_is_valid(win) then
    nvim_win_close(win, true)
  end

  win = nil
  ui_state.buffers.preview = nil
end


---Applies layout and highlight styling
---@return nil
function M.apply_layout()
  local win = ui_state.windows.preview

  if not win then
    notify("[reposcope] Preview window is not open.", 3)
    return
  end

  local ns = nvim_create_namespace("reposcope_preview")

  nvim_set_hl(ns, "ReposcopePreviewText", {
    bg = preview_config.highlight_color,
    fg = preview_config.normal_color,
    bold = true,
  })

  nvim_win_set_hl_ns(win, ns)

  nvim_set_hl(ns, "Normal", {
    bg = preview_config.highlight_color,
    fg = preview_config.normal_color,
  })
end

return M
