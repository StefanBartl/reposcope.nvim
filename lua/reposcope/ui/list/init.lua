---@class ListUI
---@brief Initializes and manages the list UI for displaying repositories
---@description
--- This module serves as the entry point for the list UI. It integrates the 
--- list window, list manager, and list configuration, providing a centralized 
--- interface for displaying and managing the list of repositories.
---
--- This ensures that the list UI is modular, flexible, and easily extendable
---@field initialize fun(): nil Initializes the list UI
---@field show_list fun(entries: string[]): nil Displays the list with the given entries
---@field clear_list fun(): nil Clears the list UI and closes the list window
---@field select_entry fun(index: number): nil Selects a specific list entry  --REF: niuy
---@field get_selected_entry fun(): string|nil Returns the currently selected list entry  --REF: niuy
local M = {}

local list_window = require("reposcope.ui.list.list_window")
local list_manager = require("reposcope.ui.list.list_manager")
local ui_state = require("reposcope.state.ui.ui_state")
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

---Displays the list with the given entries
---@param entries string[] The list of repository entries to display
---@return nil
function M.show_list(entries)
  if type(entries) ~= "table" then
    notify("[reposcope] Invalid list entries (not a table).", 4)
    return
  end

  list_manager.set_list(entries)
  notify("[reposcope] List UI displayed.", 2)
end

---Clears the list UI and closes the list window
---@return nil
function M.clear_list()
  list_manager.clear_list()
  notify("[reposcope] List UI cleared.", 2)
end

---Selects a specific list entry (highlights it)
---@param index number The index of the entry to select
---@return nil
function M.select_entry(index)
  if type(index) ~= "number" then
    notify("[reposcope] Invalid index for selection.", 4)
    return
  end

  list_window.highlight_selected(index)
  notify("[reposcope] List entry selected at index: " .. index, 2)
end

---Returns the currently selected list entry
---@return string|nil The text of the currently selected list entry
function M.get_selected_entry()
  local selected = list_manager.get_selected()
  if not selected then
    notify("[reposcope] No list entry selected.", 3)
    return nil
  end

  notify("[reposcope] Selected list entry: " .. selected, 2)
  return selected
end

return M
