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


M.row = ui_config.row
M.col = ui_config.col
M.width = ui_config.width
M.height = ui_config.height
M.color_bg = ui_config.colortheme.background
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


---Dynamically updates the background colors
---@param bg? string Optional new background color
---@return nil
function M.update_colors(bg)
  M.color_bg = bg or M.color_bg
end

return M
