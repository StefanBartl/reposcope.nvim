local M = {}

local buffers = require("reposcope.ui.state").buffers

--NOTE: Evolve to repository search func
---Proceed prompt input
---@param input string
---@return nil
local function on_enter(input)
  vim.notify("[reposcope.nvim] You searched: " .. input)
end

vim.keymap.set("i", "<CR>", function()
  local input = vim.api.nvim_get_current_line()
  vim.api.nvim_buf_delete(buffers.prompt, { force = true }) -- Eingabepuffer schließen HACK:
  on_enter(input)
end, { buffer = buffers.prompt, silent = true })

return M
