---@module 'reposcope.ui.background.background_config'
---@brief Configures the layout and appearance of the background window.
---@description
--- This module provides the configuration settings for the background window.
--- It allows for customization of the background color, transparency, border,
--- and size. These settings are applied whenever the background window is opened.

---@class BackgroundConfig : BackgroundConfigModule
local M = {}

-- Project-Specific Configuration (Global UI Config)
local ui_config = require("reposcope.ui.config")

---@type string|nil
local explicit_color_bg = nil

--- Re-derive layout and color from `ui_config`; see ui/config.lua on why
--- once-at-load was wrong. `color_bg` is re-derived from the active
--- colortheme the same way, so a theme switch via `ui.config.update_theme()`
--- is reflected here too instead of staying pinned to whatever was current
--- when this module first loaded -- unless pinned via `update_colors`.
---@return nil
function M.recompute()
  M.row = ui_config.row
  M.col = ui_config.col
  M.width = math.floor(ui_config.width)
  M.height = math.floor(ui_config.height)
  M.color_bg = explicit_color_bg or ui_config.colortheme.background
end

M.recompute()
M.border = "none"

---Dynamically updates the background layout settings
---@param row? number Optional new row position
---@param col? number Optional new column position
---@param width? number Optional new width
---@param height? number Optional new height
---@return nil
function M.update_layout(row, col, width, height)
  M.row = row or M.row
  M.col = col or M.col
  M.width = width or M.width
  M.height = height or M.height
end

---Dynamically updates the background colors. Pinned like `update_layout`:
---survives a later `recompute()` instead of being overwritten by the active
---colortheme again.
---@param bg? string Optional new background color
---@return nil
function M.update_colors(bg)
  if bg then explicit_color_bg = bg end
  M.color_bg = bg or M.color_bg
end

return M
