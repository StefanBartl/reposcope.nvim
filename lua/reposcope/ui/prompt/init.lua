---@class UIPrompt
---@brief Entry point to open the dynamic prompt layout.
---@description
--- This module initializes the full prompt UI. It creates buffers, calculates layout,
--- opens windows, sets up autocmds, and optionally starts insert mode.
---@field initialize fun(): nil Initializes the prompt UI

local M = {}

-- Config
local config = require("reposcope.config")
-- Utilities
local notify = require("reposcope.utils.debug").notify
--  Prompt Core
local prompt_autocmds = require("reposcope.ui.prompt.prompt_autocmds")
local prompt_manager = require("reposcope.ui.prompt.prompt_manager")


---Opens the prompt UI
---@returns nil
function M.initialize()
  if config.options.layout ~= "default" then
    notify("[reposcope] Unsupported prompt layout: " .. config.options.layout, 3)
    return
  end

  prompt_manager.open_windows()
  prompt_autocmds.setup_autocmds()

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

return M
