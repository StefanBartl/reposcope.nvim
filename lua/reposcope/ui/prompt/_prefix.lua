
local M = {}

local ui_state = require("reposcope.state.ui.ui_state")
local debug = require("reposcope.utils.debug")

local prefix = " " .. "\u{f002}" .. " "
M.prefix_len = vim.fn.strdisplaywidth(prefix)

---Initalize buffer for the prefix prompt window
function M.init_prompt_prefix_buf()


  if not vim.api.nvim_buf_is_valid(ui_state.buffers.prompt_prefix) then
    debug.notify("[ERROR] Prefix Buffer is not valid", 4)
    return
  end

  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "buftype", "nofile")
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "modifiable", true)
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "swapfile", false)

  vim.api.nvim_buf_set_lines(ui_state.buffers.prompt_prefix, 0, -1, false, {
    "",
    prefix })
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "modifiable", false)
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "readonly", true)
end

return M
