---@desc forward declaratioms
local default, apply_backgr_highlight

---@class UIBackground
---@field open_backgd fun(): nil Opens a large floating window and creates a named scratch buffer (`reposcope://backg`) which serves as the UI backdrop. It includes a footer legend and centers the title.
---@field default fun(): nil Creates the default floating background window.
---@field private apply_backgr_highlight fun(win: number): nil Applies the background highlight settings.
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local ui_state = require("reposcope.state.ui.ui_state")
local protected = require("reposcope.utils.protection")
local notify = require("reposcope.utils.debug").notify

---Opens a large floating window and creates a named scratch buffer (`reposcope://backg`)
---which serves as the UI backdrop. It includes a footer legend and centers the title.
function M.open_backgd()
  ui_state.buffers.backg = protected.create_named_buffer("reposcope://backg")
  vim.api.nvim_buf_set_lines(ui_state.buffers.backg, 0, -1, false, {})
  vim.bo[ui_state.buffers.backg].modifiable = false
  vim.bo[ui_state.buffers.backg].readonly = true
  vim.bo[ui_state.buffers.backg].buftype = "nofile"
  vim.bo[ui_state.buffers.backg].bufhidden = "wipe"
  vim.bo[ui_state.buffers.backg].swapfile = false

  if config.options.layout == "default" then
    default()
  else
    notify("Unknown layout: " .. config.options.layout, 3)
  end
end

---Creates the default floating background window
function default()
  ui_state.windows.backg = vim.api.nvim_open_win(ui_state.buffers.backg, false, {
    relative = "editor",
    col = ui_config.col,
    row = ui_config.row,
    height = ui_config.height,
    width = ui_config.width,
    border = "none",
    style = "minimal",
    zindex = 10,
    focusable = false,
    noautocmd = true,
  })
  apply_backgr_highlight(ui_state.windows.backg)
end

---Applies the background highlight settings to the window
---@param win number The window ID of the background window
function apply_backgr_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_backgr")
  vim.api.nvim_set_hl(ns, "Normal", { bg = ui_config.colortheme.backg, fg = "none" })
  vim.api.nvim_win_set_hl_ns(win, ns)
end

return M
