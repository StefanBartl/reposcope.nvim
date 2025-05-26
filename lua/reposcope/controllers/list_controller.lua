---@class ListController
---@brief Manages the interaction between the state and list UI.
---@description
--- The ListController is responsible for displaying the list of repositories
--- based on the current state. It does not perform API requests but only manages
--- the UI and the state interaction.
---@field display_repositories fun(): nil Displays the list of repositories from state.
local M = {}

-- UI Components (List Window and Management)
local list_window = require("reposcope.ui.list.list_window")
local list_manager = require("reposcope.ui.list.list_manager")
local list_config = require("reposcope.ui.list.list_config")
-- State Management (Repositories State)
local repositories_state = require("reposcope.state.repositories.repositories_state")
-- Utility Modules (Text Manipulation, Debugging)
local text_utils = require("reposcope.utils.text")
local notify = require("reposcope.utils.debug").notify


---Displays the list of repositories from the state.
---@return nil
function M.display_repositories()
  if not list_window.open_window() then
    notify("[reposcope] List window initialization failed.", 4)
    return
  end

  local json_data = repositories_state.get_repositories()
  if not json_data or not json_data.items then
    notify("[reposcope] No repositories loaded.", 3)
    list_manager.clear_list()
    return
  end

  -- Dynamically get the list window width  --REF: this should be get_repositories_list in state
  local list_width = math.floor(list_config.width - 1)

  local lines = {}
  for _, repo in ipairs(json_data.items) do
    local owner = repo.owner and repo.owner.login or "Unknown"
    local name = repo.name or "No name"
    local desc = repo.description or "No description"
    if type(desc) ~= "string" then
      notify(string.format("[reposcope] Skipped invalid repo description for %s/%s (type: %s)",
      repo.owner.login, repo.name, type(desc)), 3)
      desc = ""
    end
    local line = owner .. "/" .. name .. ": " .. desc
    table.insert(lines, text_utils.cut_text_for_line(0, list_width, line))
  end

  list_manager.set_list(lines)
end

return M
