--- @class UIConfiguration
--- @field width number Total width of UI
--- @field height number Total height of UI
--- @field padding number Standard padding of the UI
--- @field col number Vertical center of the UI
--- @field row number Horizontal center of the UI
local M = {}

M.width = math.floor(vim.o.columns * 0.6)
M.height = math.floor(vim.o.lines * 0.8)
M.padding = 2
M.col = math.floor((vim.o.columns - M.width) / 2)
M.row = math.floor((vim.o.lines - M.height) / 2)

return M
