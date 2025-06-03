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


-- Initial window layout: right-hand side  NOTE: Layouts
M.width = math.floor((ui_config.width * 0.5) - 3)
M.height = math.floor(ui_config.height - 2)
M.row = math.floor(ui_config.row + 1)
M.col = math.floor(ui_config.col + (ui_config.width / 2) + 2)

-- LAYOUTS! layout functionality

M.layout = {
  Normal = {
    background = ui_config.colortheme.background,
    width = math.floor(M.width - 3),
    height = math.floor(ui_config.height - 2),
    row = math.floor(ui_config.row + 1),
    col = math.floor(ui_config.col + (ui_config.width / 2) + 2),
  }
}

-- Color and border defaults
M.highlight_color = M.layout.Normal.background
M.normal_color = "#FFFFFF"
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


--- Update preview highlight and text colors
---@param highlight_color? string
---@param normal_color? string
function M.update_colors(highlight_color, normal_color)
  M.highlight_color = highlight_color or M.highlight_color
  M.normal_color = normal_color or M.normal_color
end


--- Update border layout
---@param border_layout "none"|"single"|"double"
function M.update_border(border_layout)
  M.border = border_layout or M.border
end

return M
