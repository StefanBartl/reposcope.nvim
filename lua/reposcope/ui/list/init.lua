---@module 'reposcope.ui.list.list_ui'
---@brief Entry point for initializing and restoring the repository list UI
---@description
--- This module acts as the orchestration layer for the repository list UI.
--- It integrates the list window and list manager components, and ensures
--- that any cached repository results are restored and displayed after startup.

---@class ListUI : ListUIModule
local M = {}

-- Vim Utilities
local schedule = vim.schedule
-- UI Components
local open_window = require("reposcope.ui.list.list_window").open_window
local set_and_display_list = require("reposcope.ui.list.list_manager").set_and_display_list
-- Cache Management
local get_list = require("reposcope.cache.repository_cache").get_list
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Initializes the list UI and dynamically loads if cached repositories exist.
---@return nil
function M.initialize()
  if not open_window() then
    notify("[reposcope] List initialization failed.", 4)
    return
  end

  -- Check if there are reseults from former prompt search in the list
  local actual_repo_list = get_list()
  if #actual_repo_list[1] > 1 then
    schedule(function()
      set_and_display_list(actual_repo_list)
    end)
  end
end

return M
