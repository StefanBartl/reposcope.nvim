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
-- State Management (UI State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Initializes the list UI and dynamically loads if cached repositories exist.
---@return nil
function M.initialize()
  if not list_window.open_window() then
    notify("[reposcope] List initialization failed.", 4)
    return
  end

  -- Dynamically show the list if cached repositories exist
  if ui_state.list_populated and ui_state.last_selected_line then
    local cached_repos = require("reposcope.state.repositories").get_repositories().items
    if cached_repos and #cached_repos > 0 then
      list_manager.set_list(cached_repos)
      list_window.highlight_selected(ui_state.last_selected_line)
      notify("[reposcope] List UI initialized with cached repositories.", 2)
      return
    end
  end

  list_manager.clear_list()
  notify("[reposcope] No repositories loaded. Empty list displayed.", 2)
end

return M
