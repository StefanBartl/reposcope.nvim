local M = {}

---Total width of UI
---@type number
M.width = math.floor(vim.o.columns * 0.6)
---Total height of UI
---@type number
M.height = math.floor(vim.o.lines * 0.8)
---Standard padding for UI
---@type number
M.padding = 1
---Vertical center of the UI
---@type number
M.col = math.floor((vim.o.columns - M.width) / 2)
---Horizontal center of the UI
---@type number
M.row = math.floor((vim.o.lines - M.height) / 2)

return M
