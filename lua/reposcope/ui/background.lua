---@desc forward declaratioms
local default

--- @class UIBackground
--- @field open_backgd fun(): nil Opens a large floating window and creates a named scratch buffer (`reposcope://backg`)  which serves as the UI backdrop. It includes a footer legend and centers the title
--- @field default fun(): nil Creates the default floating background window
--- @field private legend string Apply a legend of the available keymaps for Reposcope
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local state = require("reposcope.ui.state")
local protected = require("reposcope.utils.protection")

local legend = "<Esc>: Quit   <Enter>: Search  <C-r>: Readme  <?>: Keybindings"

function M.open_backgd()
  state.buffers.backg = protected.create_named_buffer("reposcope://backg")
  vim.api.nvim_buf_set_lines(state.buffers.backg, 0, -1, false, {})

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
    title = "repocope.nvim",
    title_pos = "center",
    border = "rounded",
    style = "minimal",
    noautocmd = true,
    zindex = 10,
    footer = legend,
    footer_pos = "center",
    focusable = false
  })
end

return M
