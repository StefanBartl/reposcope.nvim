---@module 'reposcope.ui.actions.filter_prompt'
---@brief Opens a floating input for filtering repository list entries
---@description
--- This module shows a `vim.ui.input()` prompt to allow users to filter the
--- currently displayed repository list by text. The input is matched against
--- the "owner/name: description" string and updates the list view accordingly.

local M = {}

-- UI + Cache
local repository_cache_get = require("reposcope.cache.repository_cache").get
local repository_cache_set = require("reposcope.cache.repository_cache").set
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local fetch_readme_for_selected = require("reposcope.controllers.provider_controller").fetch_readme_for_selected

---Prompts the user for a filter query and updates the list display
---@return nil
function M.prompt_filter()
  vim.ui.input({ prompt = "Filter repositories: " }, function(input)
    if not input or input == "" then
      return
    end

    local query = input:lower()
    local filtered = {}

    for _, repo in ipairs(repository_cache_get().items or {}) do
      local full = (repo.owner.login .. "/" .. repo.name .. ": " .. (repo.description or "")):lower()
      if full:find(query, 1, true) then
        table.insert(filtered, repo)
      end
    end

    repository_cache_set({
      total_count = #filtered,
      items = filtered
    }, false)

    display_repositories()
    fetch_readme_for_selected()
  end)
end

return M
