---@class ListUI
---@brief Initializes the list UI for displaying repositories
---@description -- REF:  TEXT
--- This module serves as the entry point for the list UI. It integrates the 
--- list window, list manager, and list configuration, providing a centralized 
--- interface for displaying and managing the list of repositories.
---
--- This ensures that the list UI is modular, flexible, and easily extendable
---@field initialize fun(): nil Initializes the list UI

local M = {}

-- UI Components (List Management and Window)
local list_window = require("reposcope.ui.list.list_window")
local list_manager = require("reposcope.ui.list.list_manager")
-- State Management
local repositories_state = require("reposcope.state.repositories.repositories_state")
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
  local actual_repo_list = repositories_state.get_repositories_list()
  if #actual_repo_list[1] > 1 then
    list_manager.set_list(actual_repo_list)  -- REF:  this should be like in list manager (formatted)
    notify("[reposcope] List UI initialized with cached repositories.", 2)
  end

  notify("[reposcope] List UI initialized.", 2)
end

return M
