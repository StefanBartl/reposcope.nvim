---@module 'reposcope.ui.list.list_ui'
---@class ListUI
---@brief Entry point for initializing and restoring the repository list UI
---@description
--- This module acts as the orchestration layer for the repository list UI.
--- It integrates the list window and list manager components, and ensures
--- that any cached repository results are restored and displayed after startup.
---
--- Responsibilities include:
--- - Creating the list UI window
--- - Checking for previously cached repository results
--- - Delegating display logic to the list manager if results exist
---
---@field initialize fun(): nil Creates the list window and displays cached repositories if available
local M = {}

-- UI Components (List Management and Window)
local list_window = require("reposcope.ui.list.list_window")
local list_manager = require("reposcope.ui.list.list_manager")
-- Cache Management
local repository_cache = require("reposcope.cache.repository_cache")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Initializes the list UI and dynamically loads if cached repositories exist.
---@return nil
function M.initialize()
  if not list_window.open_window() then
    notify("[reposcope] List initialization failed.", 4)
    return
  end

  -- Check if there are reseults from former prompt search in the list
  local actual_repo_list = repository_cache.get_list()
  if #actual_repo_list[1] > 1 then
    vim.schedule(function()
      list_manager.set_and_display_list(actual_repo_list)
    end)
  end
end

return M
