---@desc Forward declarations
local default

---@class UIPrompt Opens and initializes the prompt input window in the Reposcope UI.
---@field open_prompt fun(): nil Opens the user input prompt window in the Reposcope UI
---@field default fun(): nil Default layout for the prompt
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local prompt_config = require("reposcope.ui.prompt.config")
local prompt_autocmds = require("reposcope.ui.prompt.autocmds")
local ui_state = require("reposcope.state.ui")
local protect_prompt = require("reposcope.ui.prompt.protect_prompt_input")
local notify = require("reposcope.utils.debug").notify

---Opens the user input prompt window in the Reposcope UI
function M.open_prompt()
  ui_state.buffers.prompt = require("reposcope.utils.protection")
      .create_named_buffer("reposcope://prompt")

  if config.options.layout == "default" then
    default()
  else
    notify("Unsupported layout: " .. config.options.layout, 4)
  end

  prompt_config.init_prompt_layout(ui_state.buffers.prompt, ui_state.windows.prompt, " prompt ")
  protect_prompt.protect(ui_state.buffers.prompt, prompt_config.prefix_len)
  prompt_autocmds.setup_autocmds()

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

function default()
  ui_state.windows.prompt = vim.api.nvim_open_win(ui_state.buffers.prompt, true, {
    relative = "editor",
    row = ui_config.row,
    col = ui_config.col,
    width = (ui_config.width / 2),
    height = prompt_config.height,
    style = "minimal"
  })
end

return M
