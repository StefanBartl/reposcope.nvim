--- @desc forward declarations
local default

--- @class UIList Creates and manages the floating repository list window in the Reposcope UI.
--- @field open_list fun(): nil Creates a scratch buffer named `reposcope://list`, fills it with  predefined repository line and opens the repository floating list window in the Reposcope UI
--- @field private default fun(): nil Creates the default floating list window
--- @field private list_height integer Height of the list window
--- @field private list_row integer Row postion of the list window
--- @field private list_lines string[] Content of the list window
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local state = require("reposcope.ui.state")
local protected = require("reposcope.utils.protection")

local list_height = math.floor(ui_config.height * 0.6)
local list_row = ui_config.row + require("reposcope.ui.preview.init").height +
require("reposcope.ui.prompt.config").height + 2
local list_lines = {
  "some/repo_1: Hier steht die Kurzbeschreibung.",
  "some/repo_2: Hier steht die Kurzbeschreibung.",
  "some/repo_3: Hier steht die Kurzbeschreibung"
}

function M.open_list()
  state.buffers.list = protected.create_named_buffer("reposcope://list")
  vim.api.nvim_buf_set_lines(state.buffers.list, 0, -1, false, list_lines)

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unknown layout: " .. config.options.layout, vim.log.levels.WARN)
  end
end

function default()
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
