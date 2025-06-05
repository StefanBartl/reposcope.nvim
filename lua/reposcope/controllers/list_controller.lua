---@module 'reposcope.controllers.list_controller'
---@brief Manages the interaction between the state and list UI.
---@description
--- The ListController is responsible for displaying the list of repositories
--- based on the current state. It does not perform API requests but only manages
--- the UI and the state interaction.

---@class ListController : ListControllerModule
local M = {}

-- UI Components (List Window and Management)
local open_window = require("reposcope.ui.list.list_window").open_window
local clear_list = require("reposcope.ui.list.list_manager").clear_list
local set_and_display_list = require("reposcope.ui.list.list_manager").set_and_display_list
local list_config = require("reposcope.ui.list.list_config")
-- State Management (Repositories State)
local repository_cache_get = require("reposcope.cache.repository_cache").get
-- Utility Modules (Text Manipulation, Debugging)
local cut_text_for_line = require("reposcope.utils.text").cut_text_for_line
local notify = require("reposcope.utils.debug").notify


---Displays the list of repositories from the state.
---@return nil
function M.display_repositories()
  if not open_window() then
    notify("[reposcope] List window initialization failed.", 4)
    return
  end

  ---@type RepositoryResponse
  local json_data = repository_cache_get()
  if not json_data or not json_data.items then
    notify("[reposcope] No repositories loaded.", 3)
    clear_list()
    return
  end

  local list_width = math.floor(list_config.width - 1)

  -- Prepare local aliases for hot-loop efficiency
  ---@type Repository[]
  local items = json_data.items or {} -- Safely fallback to empty table
  local linebuf = {}                  -- Preallocated line buffer (avoids table.insert overhead)
  local fmt = string.format           -- Localize string.format to reduce global lookups
  local cut = cut_text_for_line       -- Local alias for line trimming function

  for i = 1, #items do
    local repo = items[i]

    local owner = (repo.owner and repo.owner.login) or "Unknown"
    local name = repo.name or "No name"
    local desc = repo.description

    if type(desc) ~= "string" then
      notify(fmt("[reposcope] Skipped invalid repo description for %s/%s (type: %s)", owner, name, type(desc)), 3)
      desc = "No description"
    end

    local line = fmt("%s/%s: %s", owner, name, desc)
    linebuf[#linebuf + 1] = cut(0, list_width, line)
  end

  set_and_display_list(linebuf)
end

return M
