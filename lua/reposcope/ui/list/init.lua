--- @desc forward declarations
local default, apply_list_highlight

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
local prompt_config = require("reposcope.ui.prompt.config")

function M.open_list()
  state.buffers.list = protected.create_named_buffer("reposcope://list")
  vim.bo[state.buffers.list].modifiable = false

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unknown layout: " .. config.options.layout, vim.log.levels.WARN)
  end

end

function default()
  state.windows.list = vim.api.nvim_open_win(state.buffers.list, false, {
    relative = "editor",
    row = ui_config.row + prompt_config.height,
    col = ui_config.col + 1,
    width = (ui_config.width / 2),
    height = ui_config.height - prompt_config.height,
    --title = "Repositories",
    --title_pos = "left",
    border = "none",
    style = "minimal"
  })
  apply_list_highlight(state.windows.list)
end

function apply_list_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_list")
  vim.api.nvim_set_hl(ns, "Normal", { bg =  ui_config.colortheme.backg })
  vim.api.nvim_win_set_hl_ns(win, ns)
end

return M
