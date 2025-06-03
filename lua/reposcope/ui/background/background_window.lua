---@module 'reposcope.ui.background.background_window'
---@brief Manages the background window for the UI.
---@description
--- This module is responsible for creating, configuring, and managing the 
--- background window for the UI. It provides functions to open, close, 
--- and apply layout configurations to the background window, ensuring 
--- consistent appearance across all UI components.
---
--- The background window serves as a visual base for other UI elements 
--- (Prompt, List, Preview) and can be customized via the background_config.lua.

---@class BackgroundWindow : BackgroundWindowModule
local M = {}


-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_win_close = api.nvim_win_close
local nvim_open_win = api.nvim_open_win
local nvim_set_hl = api.nvim_set_hl
-- Configuration and State Management (Background UI)
local config = require("reposcope.ui.background.background_config")
local ui_state = require("reposcope.state.ui.ui_state")
-- Utility Modules (Debugging, Protection)
local notify = require("reposcope.utils.debug").notify
local create_named_buffer = require("reposcope.utils.protection").create_named_buffer


---@private
---Applies the layout and styling to the background window.
---@return nil
local function _apply_background_layout()
  local win = ui_state.windows.backg

  if not win then
    notify("[reposcope] Background window not open.", 3)
    return
  end

  nvim_set_hl(0, "ReposcopeBackground", {
    bg = config.color_bg,
  })

  vim.wo[win].winhighlight = "Normal:ReposcopeBackground"
end

---Opens the background window.
---@return nil
function M.open_window()
  -- Check buffer and window
  local buf = ui_state.buffers.backg
  if buf and not nvim_buf_is_valid(ui_state.buffers.backg) then
    buf = nil
  end
  local win = ui_state.windows.backg
  if win and not nvim_win_is_valid(win) then
    win = nil
  end

  -- Create new buffer and assign to state table
  buf = create_named_buffer("reposcope://background")
  if not buf or not nvim_buf_is_valid(buf) then
    notify("[reposcope] Error creating background buffer.", 4)
    return
  end

  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].modifiable = false
  vim.bo[buf].bufhidden = "wipe"
  ui_state.buffers.backg = buf

  win = nvim_open_win(buf, false, {
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

  ui_state.windows.backg = win
  _apply_background_layout()
end


---Closes the background window.
---@return nil
function M.close_window()
  if ui_state.windows.backg and nvim_win_is_valid(ui_state.windows.backg) then
    nvim_win_close(ui_state.windows.backg, true)
  end
  ui_state.windows.backg = nil
  ui_state.buffers.backg = nil
end

return M
