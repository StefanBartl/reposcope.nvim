---@module 'reposcope.ui.config'
---@brief Manages the central UI configuration for reposcope.nvim.
---@description
--- This module provides the configuration settings for the entire UI (Prompt, List, Preview, Background).
--- It allows for dynamic updates to the layout (width, height, position) and color theme.
--- These settings are applied consistently across all UI components.

---@class UIConfiguration : UIConfigurationModule
local M = {}

local notify = require("reposcope.utils.debug").notify

-- Default Layout  NOTE: Layout
--
-- Fractions of the editor, not fixed cell counts -- and re-derived every time
-- the UI opens (`M.recompute`, called from `reposcope.open_ui`). They used to
-- be computed once, at the moment this module was first required, which froze
-- the geometry to whatever the editor happened to be then: resize the terminal
-- afterwards and the picker kept opening at the old size for the rest of the
-- session. There is no VimResized handler anywhere in this plugin, and
-- `update_layout` -- which would have fixed it -- was called by nothing.
M.WIDTH_FRACTION = 0.8
M.HEIGHT_FRACTION = 0.8

--- An explicit width/height set through `update_layout`, or nil to keep
--- deriving from the editor size. Remembered separately so a recompute
--- re-derives what the user did not pin, and leaves what they did.
---@type number|nil
local explicit_width = nil
---@type number|nil
local explicit_height = nil

--- Re-derive the layout from the current editor size.
---@return nil
function M.recompute()
  M.width = math.floor(explicit_width or (vim.o.columns * M.WIDTH_FRACTION))
  M.height = math.floor(explicit_height or (vim.o.lines * M.HEIGHT_FRACTION))
  M.col = math.floor((vim.o.columns - M.width) / 2)
  M.row = math.floor((vim.o.lines - M.height) / 2)
end

M.recompute()

-- Default Color Theme (Dark)
M.colortheme = {
  background = "#322931",
  prompt = "#7B7B7B",
  text = "#FFFFFF",
  accent_1 = "#E06C75",
  accent_2 = "#98C379",
}

--- Dynamically updates the layout of the UI (width, height, position)
---@param width? number Optional new width for the UI
---@param height? number Optional new height for the UI
---@param col? number Optional new column position (horizontal center)
---@param row? number Optional new row position (vertical center)
---@return nil
function M.update_layout(width, height, col, row)
  -- A value given here is a pin: it survives later recomputes, which is the
  -- only reading under which "update the layout" means anything lasting.
  if width then explicit_width = width end
  if height then explicit_height = height end
  M.recompute()
  M.col = col or M.col
  M.row = row or M.row
end

--- Applies a pre-defined theme (dark, light) or custom colors
---@param theme string The theme to apply ("dark", "light", "custom")
---@return nil
function M.update_theme(theme)
  if theme == "dark" then
    M.colortheme = {
      background = "#322931",
      prompt = "#7B7B7B",
      text = "#FFFFFF",
      accent_1 = "#E06C75",
      accent_2 = "#98C379",
    }
  elseif theme == "light" then
    M.colortheme = {
      background = "#FFFFFF",
      prompt = "#333333",
      text = "#000000",
      accent_1 = "#D32F2F",
      accent_2 = "#388E3C",
    }
  elseif theme == "custom" then
    -- Custom theme can be set dynamically
    M.colortheme = M.colortheme
  else
    notify("[reposcope] Invalid theme: " .. theme, 4)
  end
end

return M
