---@class BackgroundWindow
---@brief Manages the background window for the UI.
---@description
--- This module is responsible for creating, configuring, and managing the 
--- background window for the UI. It provides functions to open, close, 
--- and apply layout configurations to the background window, ensuring 
--- consistent appearance across all UI components.
---
--- The background window serves as a visual base for other UI elements 
--- (Prompt, List, Preview) and can be customized via the background_config.lua.
---@field open_window fun(): nil Opens the background window.
---@field close_window fun(): nil Closes the background window.
---@field apply_layout fun(): nil Applies layout and styling to the background window.
local M = {}

local config = require("reposcope.ui.background.background_config")
local ui_state = require("reposcope.state.ui.ui_state")
local notify = require("reposcope.utils.debug").notify
local protection = require("reposcope.utils.protection")

---Opens the background window.
---@return nil
function M.open_window()
  ui_state.buffers.backg = protection.create_named_buffer("reposcope://background")
  vim.bo[ui_state.buffers.backg].buftype = "nofile"
  vim.bo[ui_state.buffers.backg].modifiable = false
  vim.bo[ui_state.buffers.backg].bufhidden = "wipe"

  ui_state.windows.backg = vim.api.nvim_open_win(ui_state.buffers.backg, false, {
    relative = "editor",
    row = config.row,
    col = config.col,
    width = config.width,
    height = config.height,
    style = "minimal",
    border = config.border or "none",
    zindex =  10,
    focusable = false,
    noautocmd = true,
  })

  M.apply_layout()
end

---Closes the background window.
---@return nil
function M.close_window()
  if ui_state.windows.backg and vim.api.nvim_win_is_valid(ui_state.windows.backg) then
    vim.api.nvim_win_close(ui_state.windows.backg, true)
  end
  ui_state.windows.backg = nil
  ui_state.buffers.backg = nil
end

---Applies the layout and styling to the background window.
---@return nil
function M.apply_layout()
  if not ui_state.windows.backg then
    notify("[reposcope] Background window not open.", 3)
    return
  end

  vim.api.nvim_set_hl(0, "ReposcopeBackground", {
    bg = config.color_bg,
  })

  vim.api.nvim_win_set_option(ui_state.windows.backg, "winhighlight", "Normal:ReposcopeBackground")
end

return M
