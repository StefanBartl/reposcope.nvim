---@module 'reposcope.ui.actions.filter_repos'
---@brief Provides logic for filtering the repository list by substring
---@description
--- This module implements the logic for filtering the cached list of repositories
--- based on a case-insensitive substring query. The filtering operates on the format
--- "owner/name: description" and is intended for use with commands like
--- `:ReposcopeFilterRepos`. An empty or missing query resets the original list
--- as received from the API (sorted by relevance).

local M = {}

-- Cache
local repository_cache_get = require("reposcope.cache.repository_cache").get
local repository_cache_set = require("reposcope.cache.repository_cache").set
local restore_relevance_sorting = require("reposcope.cache.repository_cache").restore_relevance_sorting
-- UI
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local fetch_readme_for_selected = require("reposcope.controllers.provider_controller").fetch_readme_for_selected
-- Debugging
local notify = require("reposcope.utils.debug").notify


---Applies a substring filter to the current repository list or resets it if query is empty.
---@param query string Case-insensitive substring to search for
---@return nil
function M.apply_filter(query)
  query = (query or ""):lower()

  if query == "" then
    restore_relevance_sorting()
    notify("[reposcope] Filter cleared – showing all repositories", vim.log.levels.INFO)
    return
  end

  local filtered = {}
  for _, repo in ipairs(repository_cache_get().items or {}) do
    local full = (repo.owner.login .. "/" .. repo.name .. ": " .. (repo.description or "")):lower()
    if full:find(query, 1, true) then
      table.insert(filtered, repo)
    end
  end

  repository_cache_set({ total_count = #filtered, items = filtered }, false)
  display_repositories()
  fetch_readme_for_selected()
end

return M
