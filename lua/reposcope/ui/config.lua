---@class UIConfiguration
---@field width number Total width of UI
---@field height number Total height of UI
---@field col number Vertical center of the UI
---@field row number Horizontal center of the UI
---@field colortheme table<string, string> Color theme settings for the UI
local M = {}

M.width = math.floor(vim.o.columns * 0.8)
M.height = math.floor(vim.o.lines * 0.8)
M.col = math.floor((vim.o.columns - M.width) / 2)
M.row = math.floor((vim.o.lines - M.height) / 2)
M.preview_width = (M.width / 2) + 2
M.colortheme = {
  backg = "#322931",
  prompt = "#7B7B7B",
  text = "#FFFFFF",
  accent_1 = "#E06C75",
  accent_2 = "#98C379",
}

return M
