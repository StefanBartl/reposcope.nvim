local M = {}
local ui_config = require("reposcope.ui.config")
local windows = require("reposcope.ui.state").windows
local buffers = require("reposcope.ui.state").buffers
local protect_prompt = require("reposcope.ui.prompt.protect_prompt_input")
local prompt_config = require("reposcope.ui.prompt.config")
local preview = require("reposcope.ui.preview.preview")
require("reposcope.ui.prompt.prompt_keymaps")

---Opens the ui-prompt
---@return nil
function M.open_prompt()
  buffers.prompt = vim.api.nvim_create_buf(false, true)
  windows.prompt = vim.api.nvim_open_win(buffers.prompt, true, {
    relative = "editor",
    row = ui_config.row + preview.height, -- TODO: This will change to new path pf preview config
    col = ui_config.col + 1,
    width = ui_config.width - 2,
    height = prompt_config.height,
    border = "single",
    title = "Search Repositories",
    title_pos = "center",
    style = 'minimal',
  })

  prompt_config.apply_prompt_config(buffers.prompt, windows.prompt)
  protect_prompt.protect(buffers.prompt, prompt_config.len)

  -- Change mode to insert
  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

return M
