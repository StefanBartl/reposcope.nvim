---@class UIConfiguration
---@brief Manages the central UI configuration for reposcope.nvim.
---@description
--- This module provides the configuration settings for the entire UI (Prompt, List, Preview, Background).
--- It allows for dynamic updates to the layout (width, height, position) and color theme.
--- These settings are applied consistently across all UI components.
---
--- The module also supports theme customization, enabling different color schemes.
---@field width number Total width of UI
---@field height number Total height of UI
---@field col number Horizontal center of the UI
---@field row number Vertical center of the UI
---@field colortheme table<string, string> Color theme settings for the UI
---@field update_layout fun(width?: number, height?: number, col?: number, row?: number): nil Dynamically updates the UI layout settings
---@field update_theme fun(theme: string): nil Applies a pre-defined theme (e.g., "dark", "light")
local M = {}

-- Default Layout
M.width = math.floor(vim.o.columns * 0.8)
M.height = math.floor(vim.o.lines * 0.8)
M.col = math.floor((vim.o.columns - M.width) / 2)
M.row = math.floor((vim.o.lines - M.height) / 2)
--M.preview_width = math.floor(M.width * 0.5)  --REF: Why here? circ dep

-- Default Color Theme (Dark)  TEST:
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
  M.width = width or M.width
  M.height = height or M.height
  M.col = col or math.floor((vim.o.columns - M.width) / 2)
  M.row = row or math.floor((vim.o.lines - M.height) / 2)
  M.preview_width = math.floor(M.width * 0.5)
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
    require("reposcope.utils.debug").notify("[reposcope] Invalid theme: " .. theme, 4)
  end
end

return M
