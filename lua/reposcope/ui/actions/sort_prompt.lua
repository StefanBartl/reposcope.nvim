---@module 'reposcope.ui.actions.sort_prompt'
---@brief Interactive sort selection with UI select
---@description
--- Presents an interactive selection menu to the user to sort the current
--- repository list by various criteria. Applies sorting and refreshes README.

local M = {}

local repository_cache = require("reposcope.cache.repository_cache")
local list_controller = require("reposcope.controllers.list_controller")
local fetch_readme = require("reposcope.controllers.provider_controller").fetch_readme_for_selected
local notify = require("reposcope.utils.debug").notify

---@private
---@brief Sorts repository items based on the selected mode
---@param items Repository[]
---@param mode "name"|"owner"|"stars"
---@return Repository[]|nil
local function sort_items(items, mode)
  if mode == "name" then
    table.sort(items, function(a, b) return a.name < b.name end)
  elseif mode == "owner" then
    table.sort(items, function(a, b) return a.owner.login < b.owner.login end)
  elseif mode == "stars" then
    table.sort(items, function(a, b)
      return (a.stargazers_count or 0) > (b.stargazers_count or 0)
    end)
  else
    return nil
  end
  return items
end

---Displays a prompt to sort the currently cached repositories by mode.
---@return nil
function M.prompt_sort()
  vim.ui.select({ "name", "owner", "stars", "relevance" }, {
    prompt = "Sort repositories by:",
  }, function(choice)
    if not choice then return end

    if choice == "relevance" then
      repository_cache.restore_relevance_sorting()
    else
      local items = repository_cache.get().items or {}
      if #items == 0 then
        notify("[reposcope] No repositories to sort.", vim.log.levels.WARN)
        return
      end

      local sorted = sort_items(vim.tbl_deep_extend("force", {}, items), choice)
      if sorted then
        repository_cache.set({ total_count = #sorted, items = sorted }, false)
      end
    end

    list_controller.display_repositories()
    fetch_readme()
  end)
end

return M

