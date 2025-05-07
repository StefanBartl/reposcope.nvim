---@desc forward declaratioms
local default, apply_backgr_highlight

--- @class UIBackground
--- @field open_backgd fun(): nil Opens a large floating window and creates a named scratch buffer (`reposcope://backg`)  which serves as the UI backdrop. It includes a footer legend and centers the title
--- @field default fun(): nil Creates the default floating background window
--- @field private legend string Apply a legend of the available keymaps for Reposcope
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local state = require("reposcope.ui.state")
local protected = require("reposcope.utils.protection")

function M.open_backgd()
  state.buffers.backg = protected.create_named_buffer("reposcope://backg")
  vim.api.nvim_buf_set_lines(state.buffers.backg, 0, -1, false, {})
  vim.bo[state.buffers.backg].modifiable = false
  vim.bo[state.buffers.backg].readonly = true
  vim.bo[state.buffers.backg].buftype = "nofile"
  vim.bo[state.buffers.backg].bufhidden = "wipe"
  vim.bo[state.buffers.backg].swapfile = false

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unknown layout: " .. config.options.layout, vim.log.levels.WARN)
  end
end


function default()
  state.windows.backg = vim.api.nvim_open_win(state.buffers.backg, false, {
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
  apply_backgr_highlight(state.windows.backg)
end

function apply_backgr_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_backgr")
  vim.api.nvim_set_hl(ns, "Normal", { bg = ui_config.colortheme.backg, fg ="none" })
  vim.api.nvim_win_set_hl_ns(win, ns)
end

return M
