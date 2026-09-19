---@module 'reposcope.ui.preview.preview_config'
---@brief Provides layout and style settings for the README preview window.
---@description
---The `PreviewConfig` module defines the layout, position, colors, and border type
---for the preview window in Reposcope. It ensures consistency in how preview content
---is displayed and allows dynamic updates for layout or styling.
---This structure matches other UI modules like list and background.
---
---The config is consumed by `preview_window.lua`

---@class PreviewConfig : PreviewConfigModule
local M = {}

-- Project-Specific Configuration
local ui_config = require("reposcope.ui.config")

---@type string|nil
local explicit_highlight_color = nil
---@type string|nil
local explicit_normal_color = nil

-- LAYOUTS! layout functionality
M.layout = { Normal = {} }

-- Initial window layout: right-hand side  NOTE: Layouts
--- Re-derive from `ui_config`, which is itself re-derived on every UI open.
--- Computed once at load, these froze together with it. Colors are
--- re-derived from the active colortheme the same way, so a theme switch via
--- `ui.config.update_theme()` is reflected here too, instead of staying
--- pinned to whichever hex values were current when this module first
--- loaded (ERR-53); `highlight_color`/`normal_color` stay pinnable via
--- `update_colors`, same as `update_layout`'s width/height.
---@return nil
function M.recompute()
  M.width = math.floor((ui_config.width * 0.5) - 3)
  M.height = math.floor(ui_config.height - 2)
  M.row = math.floor(ui_config.row + 1)
  M.col = math.floor(ui_config.col + (ui_config.width / 2) + 2)

  M.layout.Normal.background = ui_config.colortheme.background
  M.layout.Normal.width = math.floor(M.width - 3)
  M.layout.Normal.height = math.floor(ui_config.height - 2)
  M.layout.Normal.row = math.floor(ui_config.row + 1)
  M.layout.Normal.col = math.floor(ui_config.col + (ui_config.width / 2) + 2)

  M.highlight_color = explicit_highlight_color or M.layout.Normal.background
  M.normal_color = explicit_normal_color or ui_config.colortheme.text
end

M.recompute()

M.border = "none"

--- Dynamically update the preview layout
---@param width? number
---@param height? number
---@param row? number
---@param col? number
function M.update_layout(width, height, row, col)
  M.width = width or M.width
  M.height = height or M.height
  M.row = row or M.row
  M.col = col or M.col
end

--- Update preview highlight and text colors. Pinned like `update_layout`'s
--- width/height: survives a later `recompute()` instead of being
--- overwritten by the active colortheme again.
---@param highlight_color? string
---@param normal_color? string
function M.update_colors(highlight_color, normal_color)
  if highlight_color then explicit_highlight_color = highlight_color end
  if normal_color then explicit_normal_color = normal_color end
  M.highlight_color = highlight_color or M.highlight_color
  M.normal_color = normal_color or M.normal_color
end

--- Update border layout
---@param border_layout "none"|"single"|"double"
function M.update_border(border_layout) M.border = border_layout or M.border end

return M
