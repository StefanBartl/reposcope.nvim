local M = {}

local state = require("reposcope.ui.state")

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

--- Set a keymap for multiple buffers
--- @param modes string|string[] Mode(s), e.g. "n" or {"n", "i"}
--- @param lhs string Key sequence (e.g. "<C-c>")
--- @param rhs function|string Callback function or command string
--- @param bufs number[] List of buffer handles
--- @param opts table|nil Additional keymap options
--- @return nil
function M.map_over_bufs(modes, lhs, rhs, bufs, opts)
  opts = opts or {}
  for _, buf in ipairs(bufs) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      vim.keymap.set(modes, lhs, rhs, vim.tbl_extend("force", opts, { buffer = buf }))
      vim.notify(string.format("[reposcope] keymap set for buf %d: %s", buf, lhs), vim.log.levels.DEBUG)
    else
      vim.notify(string.format("[reposcope] invalid or nil buffer for keymap: %s", vim.inspect(buf)), vim.log.levels.DEBUG)
    end
  end
end

--- Delete a keymap from multiple buffers
--- @param modes string|string[]
--- @param lhs string
--- @param bufs number[]
function M.unmap_over_bufs(modes, lhs, bufs)
  for _, buf in ipairs(bufs) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.keymap.del, modes, lhs, { buffer = buf })
      vim.notify(string.format("[reposcope] keymap removed from buf %d: %s", buf, lhs), vim.log.levels.DEBUG)
    end
  end
end

-- Apply `<C-e>` keymap to close UI on relevant buffers
--- @return nil
function M.set_close_ui_keymaps()
  M.map_over_bufs({ "i", "n", "t" }, "<Esc>", function()
    print("[reposcope] close_ui triggered via <C-e>")
    require("reposcope.ui.start").close_ui()
  end, {
    state.buffers.backg,
    state.buffers.preview,
    state.buffers.prompt,
    state.buffers.list,
  }, { silent = true })
end

--- Remove the <C-e> keymap from all UI buffers
--- @return nil
function M.unset_close_ui_keymaps()
  M.unmap_over_bufs({ "i", "n", "t" }, "<Esc>", {
    state.buffers.backg,
    state.buffers.preview,
    state.buffers.prompt,
    state.buffers.list,
  })
end

return M
