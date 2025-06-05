---@module 'reposcope.ui.list.list_config'
---@brief Manages the configuration settings for the list window
---@description
---This module provides the configuration settings for the list window.
---It allows for customization of the list layout (size, position) and colors.
---These settings ensure consistent appearance and behavior of the list UI.

---@class ListConfig : ListConfigModule
local M = {}

-- Default Layout (List is on the left side, taking 40% of the width)  NOTE: Layouts
M.width = math.floor(vim.o.columns * 0.4)
M.height = math.floor(vim.o.lines * 0.8)
M.row = math.floor((vim.o.lines - M.height) / 2)
M.col = 0

-- Default Colors (Dark Theme)
M.highlight_color = "#44475a" -- Color for the selected line
M.normal_color = "#0eea36"    -- Default text color
M.border = "none"


---Dynamically updates the layout of the list window
---@param width? number Optional new width for the list window
---@param height? number Optional new height for the list window
---@param row? number Optional new row position
---@param col? number Optional new column position
---@return nil
function M.update_layout(width, height, row, col)
  M.width = math.floor(width or M.width)
  M.height = math.floor(height or M.height)
  M.row = row or M.row
  M.col = col or M.col
end

---Dynamically updates the colors of the list window
---@param highlight_color? string Optional new highlight color
---@param normal_color? string Optional new normal text color
---@return nil
function M.update_colors(highlight_color, normal_color)
  M.highlight_color = highlight_color or M.highlight_color
  M.normal_color = normal_color or M.normal_color
end

---Dynamically updates the border layout
---@param border_layout "none"|"single"|"double" Border layout
---@return nil
function M.update_border(border_layout)
  M.border = border_layout or M.border
end

return M
