---@description Opens and initializes the prompt input window in the Reposcope UI.
---@see reposcope.ui.state
---@see reposcope.ui.config
---@see reposcope.ui.preview.init
---@see reposcope.ui.prompt.config
---@see reposcope.ui.prompt.protect_prompt_input

local M = {}

local ui_config = require("reposcope.ui.config")
local protect_prompt = require("reposcope.ui.prompt.protect_prompt_input")
local prompt_config = require("reposcope.ui.prompt.config")
local preview = require("reposcope.ui.preview.init")
local state = require("reposcope.ui.state")
require("reposcope.ui.prompt.prompt_keymaps") -- applies mappings globally when required

--- Opens the user input prompt window in the Reposcope UI.
---
--- Creates a scratch buffer named `reposcope://prompt` and opens it in a
--- floating window directly below the preview window. Configures input protection,
--- applies input-specific window options and sets mode to insert.
---
--- @protected
--- @return nil
function M.open_prompt()
  state.buffers.prompt = require("reposcope.utils.protection")
    .create_named_buffer("reposcope://prompt")
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

  -- apply window and buffer-local settings for the prompt
  prompt_config.apply_prompt_config(state.buffers.prompt, state.windows.prompt)

  -- protect user input from accidental deletion
  protect_prompt.protect(state.buffers.prompt, prompt_config.len)

  -- enter insert mode after window appears
  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

return M
