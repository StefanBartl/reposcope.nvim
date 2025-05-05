--- @desc forward declarations
local default

--- @class UIPreview
--- @field open_preview fun(): nil Creates a scratch buffer named `reposcope://preview` and opens the preview window in the Reposcope UI
--- @field default fun(): nil Creates the default floating preview window
--- @field private lines string[] Preview content to display in the buffer
--- @field height number Height of the preview window
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local state = require("reposcope.ui.state")
local protected = require("reposcope.utils.protection")

local lines = {
  "Ab hier Previewline",
  "Lorem preview ips",
  "Lorem pre",
  "ipsum ipsm",
  "fünfte previw"
}

M.height = protected.count_or_default(M.lines, 6)

function M.open_preview()
  state.buffers.preview = protected.create_named_buffer("reposcope://preview")
  vim.api.nvim_buf_set_lines(state.buffers.preview, 0, -1, false, lines)

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unsupported layout: " .. config.options.layout, vim.log.levels.ERROR)
  end
end

--ADD: Inject repo infos or/and readme
--ADD: Ability to scroll
function default()
  state.windows.preview = vim.api.nvim_open_win(state.buffers.preview, false, {
    relative = "editor",
    col = ui_config.col + ui_config.padding,
    row = ui_config.row + 1,
    height = M.height - ui_config.padding,
    width = ui_config.width - ui_config.padding,
    border = "none",
    title = "Preview",
    title_pos = "center",
    style = "minimal",
  })
end

return M
