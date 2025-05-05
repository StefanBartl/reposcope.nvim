---@description Creates and manages the floating repository list window in the Reposcope UI.
---@see reposcope.ui.state
---@see reposcope.utils.protection
---@see reposcope.ui.config
---@see reposcope.ui.preview
---@see reposcope.ui.prompt.config

local M = {}

local state = require("reposcope.ui.state")
local protected = require("reposcope.utils.protection")
local ui_config = require("reposcope.ui.config")

--- @type integer
--- @private
local list_height = math.floor(ui_config.height * 0.6)

--- @type integer
--- @private
local list_row = ui_config.row + require("reposcope.ui.preview.init").height + require("reposcope.ui.prompt.config").height + 2

--- @type string[]
--- @private
local list_lines = {
  "some/repo_1: Hier steht die Kurzbeschreibung.",
  "some/repo_2: Hier steht die Kurzbeschreibung.",
  "some/repo_3: Hier steht die Kurzbeschreibung"
}

--- Opens the repository list window in the Reposcope UI.
---
--- Creates a scratch buffer named `reposcope://list` and fills it with
--- predefined repository lines. Then opens the buffer in a floating minimal window.
---
--- @protected
--- @return nil
function M.open_list()
  state.buffers.list = protected.create_named_buffer("reposcope://list")
  vim.api.nvim_buf_set_lines(state.buffers.list, 0, -1, false, list_lines)
  state.windows.list = vim.api.nvim_open_win(state.buffers.list, false, {
    relative = "editor",
    row = list_row,
    col = ui_config.col + ui_config.padding,
    width = ui_config.width - ui_config.padding,
    height = list_height,
    title = "Repositories",
    title_pos = "left",
    border = "none",
    style = "minimal",
  })
end

return M
