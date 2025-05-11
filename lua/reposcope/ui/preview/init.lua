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
local preview_width = ui_config.preview_width
local banner = require("reposcope.ui.preview.banner").get_banner

---Creates a scratch buffer named `reposcope://preview` and opens the preview window in the Reposcope UI
function M.open_preview()
  ui_state.buffers.preview = protected.create_named_buffer("reposcope://preview")
  vim.api.nvim_buf_set_lines(ui_state.buffers.preview, 0, -1, false, banner(preview_width))
  vim.bo[ui_state.buffers.preview].modifiable = false
  vim.bo[ui_state.buffers.preview].readonly = true
  vim.bo[ui_state.buffers.preview].buftype = "nofile"

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unsupported layout: " .. config.options.layout, 4)
  end
end

--ADD: Inject repo infos or/and readme
function default()
  ui_state.windows.preview = vim.api.nvim_open_win(ui_state.buffers.preview, false, {
    relative = "editor",
    col = ui_config.col + (ui_config.width / 2) + 1,
    row = ui_config.row,
    height = ui_config.height,
    width = ui_config.preview_width,
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
