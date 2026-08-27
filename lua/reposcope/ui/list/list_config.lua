---@module 'reposcope.ui.list.list_config'
---@brief Manages the configuration settings for the list window
---@description
---This module provides the configuration settings for the list window.
---It allows for customization of the list layout (size, position) and colors.
---These settings ensure consistent appearance and behavior of the list UI.

---@class ListConfig : ListConfigModule
local M = {}

-- Project-Specific Configuration
local ui_config = require("reposcope.ui.config")

-- Default Layout (List is on the left side, taking 40% of the width)  NOTE: Layouts
-- Re-derived on every UI open; see ui/config.lua on why once-at-load was wrong.
M.WIDTH_FRACTION = 0.4
M.HEIGHT_FRACTION = 0.8

---@type number|nil
local explicit_width = nil
---@type number|nil
local explicit_height = nil

--- Re-derive the list layout from the current editor size.
---@return nil
function M.recompute()
  M.width = math.floor(explicit_width or (vim.o.columns * M.WIDTH_FRACTION))
  M.height = math.floor(explicit_height or (vim.o.lines * M.HEIGHT_FRACTION))
  M.row = math.floor((vim.o.lines - M.height) / 2)
  M.col = 0
end

M.recompute()

-- Default Colors, sourced from the active colortheme (so a theme/colorscheme
-- switch via `ui.config.update_theme()` is reflected here too, instead of
-- these staying pinned to the original dark-theme hex values)
M.highlight_color = ui_config.colortheme.accent_1 -- Color for the selected line
M.normal_color = ui_config.colortheme.text -- Default text color
M.border = "none"

---Dynamically updates the layout of the list window
---@param width? number Optional new width for the list window
---@param height? number Optional new height for the list window
---@param row? number Optional new row position
---@param col? number Optional new column position
---@return nil
function M.update_layout(width, height, row, col)
  if width then explicit_width = width end
  if height then explicit_height = height end
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
function M.update_border(border_layout) M.border = border_layout or M.border end

return M
