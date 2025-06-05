---@module 'reposcope.ui.prompt.init'
---@brief Entry point to open the dynamic prompt layout.
---@description
--- This module initializes the full prompt UI. It creates buffers, calculates layout,
--- opens windows, sets up autocmds, and optionally starts insert mode.

---@class UIPrompt : UIPromptModule
local M = {}

-- Config
local config = require("reposcope.config")
--  Prompt Core
local prompt_setup_autocmds = require("reposcope.ui.prompt.prompt_autocmds").setup_autocmds
local prompt_manager_open_windows = require("reposcope.ui.prompt.prompt_manager").open_windows
-- Utilities
local notify = require("reposcope.utils.debug").notify


---Opens the prompt UI
---@returns nil
function M.initialize()
  if config.options.layout ~= "default" then  -- REF: If layouts are implemented, change
    notify("[reposcope] Unsupported prompt layout: " .. config.options.layout, 3)
    config.options.layout = "default"
  end

  prompt_manager_open_windows()
  prompt_setup_autocmds()

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

return M
