---@description Creates the background window for the Reposcope UI.
---@see reposcope.ui.state
---@see reposcope.ui.config
---@see reposcope.utils.protection

local state = require("reposcope.ui.state")
local ui_config = require("reposcope.ui.config")

local M = {}

--- @type string
--- @private
local legend = "<Esc>: Quit   <Enter>: Search  <C-r>: Readme  <?>: Keybindings"

--- Opens the background window for the Reposcope UI.
---
--- This function creates a named scratch buffer (`reposcope://backg`)
--- and opens it in a large floating window which serves as the UI backdrop.
--- It includes a footer legend and centers the title.
---
--- @protected
--- @return nil
function M.open_backgd()
  state.buffers.backg = require("reposcope.utils.protection")
    .create_named_buffer("reposcope://backg")

  vim.api.nvim_buf_set_lines(state.buffers.backg, 0, -1, false, {})

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
    --focusable = false
  })
end

return M
