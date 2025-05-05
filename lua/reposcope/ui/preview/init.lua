---@description Manages the preview window in the Reposcope UI.
---@see reposcope.ui.state
---@see reposcope.utils.protection
---@see reposcope.ui.config

local M = {}

local state = require("reposcope.ui.state")
local protected = require("reposcope.utils.protection")
local ui_config = require("reposcope.ui.config")

--- Preview content to display in the buffer
--- @type string[]
local lines = {
  "Ab hier Previewline",
  "Lorem preview ips",
  "Lorem pre",
  "ipsum ipsm",
  "fünfte previw"
}

--- @type integer
M.height = protected.count_or_default(M.lines, 6)

--- Opens the preview window in the Reposcope UI.
---
--- Creates a scratch buffer named `reposcope://preview`,
--- fills it with preview content and opens a floating window.
---
--- @protected
--- @return nil
function M.open_preview()
  state.buffers.preview = protected.create_named_buffer("reposcope://preview")
  vim.api.nvim_buf_set_lines(state.buffers.preview, 0, -1, false, lines)
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
