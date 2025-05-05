--- @desc Forward declarations
local default

--- @class UIPrompt Opens and initializes the prompt input window in the Reposcope UI.
--- @field open_prompt fun(): nil Opens the user input prompt window in the Reposcope UI
--- @field default fun(): nil Default layout for the prompt
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local prompt_config = require("reposcope.ui.prompt.config")
local state = require("reposcope.ui.state")
local protect_prompt = require("reposcope.ui.prompt.protect_prompt_input")
local preview = require("reposcope.ui.preview.init")

--- Creates a scratch buffer named `reposcope://prompt` and opens it in a
--- floating window directly below the preview window. Configures input protection,
--- applies input-specific window options and sets mode to insert.
function M.open_prompt()
  state.buffers.prompt = require("reposcope.utils.protection")
   .create_named_buffer("reposcope://prompt")

  if config.options.layout == "default" then
    default()
  else
    vim.notify("Unsupported layout: " .. config.options.layout, vim.log.levels.ERROR)
  end

  prompt_config.apply_prompt_config(state.buffers.prompt, state.windows.prompt)
  protect_prompt.protect(state.buffers.prompt, prompt_config.len)

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

function default()
  state.windows.prompt = vim.api.nvim_open_win(state.buffers.prompt, true, {
    relative = "editor",
    row = ui_config.row + preview.height,
    col = ui_config.col + 1,
    width = ui_config.width - 2,
    height = prompt_config.height,
    border = "single",
    title = "Search Repositories",
    title_pos = "center",
    style = "minimal",
  })
end

return M
