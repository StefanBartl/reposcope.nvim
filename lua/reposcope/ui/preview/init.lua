---@desc forward declarations
local default, apply_preview_highlight

---@class UIPreview
---@field open_preview fun(): nil Creates a scratch buffer named `reposcope://preview` and opens the preview window in the Reposcope UI
---@field default fun(): nil Creates the default floating preview window
---@field height number Height of the preview window
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local ui_state = require("reposcope.state.ui")
local protected = require("reposcope.utils.protection")
local text = require("reposcope.utils.text")

M.preview_width = (ui_config.width / 2) + 2
local lines = {
  text.center_text("No preview available", M.preview_width)
}
M.height = protected.count_or_default(lines, 1)

---Creates a scratch buffer named `reposcope://preview` and opens the preview window in the Reposcope UI
function M.open_preview()
  ui_state.buffers.preview = protected.create_named_buffer("reposcope://preview")
  vim.api.nvim_buf_set_lines(ui_state.buffers.preview, 0, -1, false, lines)
  vim.bo[ui_state.buffers.preview].modifiable = false
  vim.bo[ui_state.buffers.preview].readonly = true
  vim.bo[ui_state.buffers.preview].buftype = "nofile"

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unsupported layout: " .. config.options.layout, vim.log.levels.ERROR)
  end
end

--ADD: Inject repo infos or/and readme
function default()
  ui_state.windows.preview = vim.api.nvim_open_win(ui_state.buffers.preview, false, {
    relative = "editor",
    col = ui_config.col + (ui_config.width / 2) + 1,
    row = ui_config.row,
    height = ui_config.height,
    width = M.preview_width,
    border = "none",
    title = "Preview",
    title_pos = "center",
    style = "minimal",
    focusable = false,
    noautocmd = true,
  })
  apply_preview_highlight(ui_state.windows.preview)
end

function apply_preview_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_preview")
  vim.api.nvim_set_hl(ns, "Normal", { bg = ui_config.colortheme.backg })
  vim.api.nvim_win_set_hl_ns(win, ns)
end

return M
