local M = {}

local state = require("reposcope.ui.state")

function M.map_over_bufs(mode, key, fn, bufs, opts)
  opts = opts or {}
  for _, buf in ipairs(bufs) do
    vim.keymap.set(mode, key, fn, vim.tbl_extend("force", opts, { buffer = buf }))
  end
end

--NOTE: Evolve to repository search func
---Proceed prompt input
---@param input string
---@return nil
local function on_enter(input)
  vim.notify("[reposcope.nvim] You searched: " .. input)
end

--NOTE:Maybe collect all keymaps and naem ot set_ui_keymaps 
function M.set_prompt_keymaps()
  vim.keymap.set("i", "<CR>", function()
    local input = vim.api.nvim_get_current_line()
    on_enter(input)
  end, { buffer = state.buffers.prompt, silent = true })
end

function M.unset_prompt_keymaps()
  vim.keymap.del("i", "<CR>", { buffer =  state.buffers.prompt })
end

return M
