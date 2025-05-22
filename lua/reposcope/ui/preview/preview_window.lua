---@class PreviewWindow
---@brief Manages the preview window for displaying repository README content.
---@description
---The `PreviewWindow` module is responsible for creating and configuring the preview window.
---It handles the layout, visual styling, and content injection from cached or live README sources.
---This window is typically opened alongside the list and prompt components and is non-focusable.
---
---The layout is defined in `preview_config.lua` and supports dynamic updates
---@field open_window fun(): boolean Opens the preview window with layout and banner and returns true or false
---@field close_window fun(): nil Closes the preview window if open
---@field apply_layout fun(): nil Applies visual styling (highlight, background) to the preview window
local M = {}

-- Configuration (Global and UI-Specific)
local preview_config = require("reposcope.ui.preview.preview_config")
-- State Management (UI State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Protection and Error Handling
local protection = require("reposcope.utils.protection")
local notify = require("reposcope.utils.debug").notify


---Opens the preview window and injects the initial banner
---@return boolean
function M.open_window()
  -- Reset buffer and/or if invalid  REF:
  if ui_state.buffers.preview and not vim.api.nvim_buf_is_valid(ui_state.buffers.preview) then
    ui_state.buffers.preview = nil
  end
  if ui_state.windows.preview and not vim.api.nvim_win_is_valid(ui_state.windows.preview) then
    ui_state.windows.preview = nil
  end

  if not ui_state.buffers.preview or not vim.api.nvim_buf_is_valid(ui_state.buffers.preview) then
    local buf = protection.create_named_buffer("reposcope://preview")
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      notify("[reposcope] Preview buffer cannot be created.", 4)
      return false
    end

    ui_state.buffers.preview = buf
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].modifiable = true
    vim.bo[buf].bufhidden = "wipe"

    local win = vim.api.nvim_open_win(buf, false, {
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
    notify("[reposcope] Preview window initialized.", 2)
    return true
  else
    notify("[reposcope] Preview window already exists.", 2)
    return true
  end
end


---Closes the preview window
function M.close_window()
  if ui_state.windows.preview and vim.api.nvim_win_is_valid(ui_state.windows.preview) then
    vim.api.nvim_win_close(ui_state.windows.preview, true)
  end
  ui_state.windows.preview = nil
  ui_state.buffers.preview = nil
end


---Applies layout and highlight styling
function M.apply_layout()
  if not ui_state.windows.preview then
    notify("[reposcope] Preview window is not open.", 3)
    return
  end

  local ns = vim.api.nvim_create_namespace("reposcope_preview")

  vim.api.nvim_set_hl(ns, "ReposcopePreviewText", {
    bg = preview_config.highlight_color,
    fg = preview_config.normal_color,
    bold = true,
  })

  vim.api.nvim_win_set_hl_ns(ui_state.windows.preview, ns)

  vim.api.nvim_set_hl(ns, "Normal", {
    bg = preview_config.highlight_color,
    fg = preview_config.normal_color,
  })

  notify("[reposcope] Preview layout and styling applied.", 2)
end

return M
