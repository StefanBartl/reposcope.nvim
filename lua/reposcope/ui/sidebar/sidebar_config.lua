---@module 'reposcope.ui.sidebar.sidebar_config'
---@brief Layout for the narrow left sidebar (active filter/sort/result-count overview).
---@description
--- Mirrors the shape of `list_config.lua`/`preview_config.lua`: static layout
--- values derived from `ui_config`, recomputed by callers rather than reacting
--- to config changes automatically (matches every other UI layout module).

---@class SidebarConfig : SidebarConfigModule
local M = {}

-- Project-Specific Configuration
local ui_config = require("reposcope.ui.config")
local prompt_config = require("reposcope.ui.prompt.prompt_config")

M.width = 22
M.row = math.floor(ui_config.row + prompt_config.height + 1)
M.col = math.floor(ui_config.col + 1)
M.height = math.floor(ui_config.height - prompt_config.height - 2)
M.border = "none"

---Dynamically updates the sidebar layout
---@param width? number
---@param row? number
---@param col? number
---@param height? number
---@return nil
function M.update_layout(width, row, col, height)
  M.width = width or M.width
  M.row = row or M.row
  M.col = col or M.col
  M.height = height or M.height
end

return M
