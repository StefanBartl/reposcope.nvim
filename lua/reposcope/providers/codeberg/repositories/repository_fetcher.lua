---@module 'reposcope.providers.codeberg.repositories.repository_fetcher'
---@brief Fetches repositories from the Codeberg (Gitea) API and updates the local cache.
---@description
--- This module is responsible for building the Codeberg API request URL,
--- sending the repository search request, decoding the response, normalizing
--- Codeberg's (Gitea) repo JSON into the shared `Repository` shape, and
--- storing the result in the internal repository cache. It does not interact
--- with the user interface.

---@class CodebergRepositoryFetcher : RepositoryFetcherModule
local M = {}

-- API Request
local client_request = require("reposcope.network.clients.api_client").request
-- State & Cache
local repo_cache_set = require("reposcope.cache.repository_cache").set
local repo_cache_clear = require("reposcope.cache.repository_cache").clear
-- Utilities
local notify = require("reposcope.utils.debug").notify
local urlencode = require("reposcope.utils.encoding").urlencode

-- Constants
local CODEBERG_API_SEARCH_URL = "https://codeberg.org/api/v1/repos/search?q=%s"


---Builds the full Codeberg API URL from a query
---@param query string
---@return string
function M.build_url(query)
  local encoded_query = urlencode(query or "")
  return string.format(CODEBERG_API_SEARCH_URL, encoded_query)
end


---@private
---Normalizes a single Codeberg (Gitea) repo object into the shared `Repository` shape
---@param repo table
---@return Repository
local function _normalize(repo)
  return {
    name = repo.name,
    description = repo.description or "",
    html_url = repo.clone_url or repo.html_url,
    owner = { login = repo.owner and repo.owner.login or "" },
    default_branch = repo.default_branch,
    stargazers_count = repo.stars_count,
  }
end


--- Fetches repositories from the Codeberg API and updates the repository cache
---@param query string The search query for Codeberg repositories
---@param on_success fun(): nil Callback if the fetch succeeds
---@param on_failure fun(): nil Callback if the fetch fails
---@return nil
function M.fetch_repositories(query, on_success, on_failure)
  if query == "" then
    notify("[reposcope] Error: Search query is empty.", 4)
    on_failure()
    return
  end

  local url = M.build_url(query)

  client_request("GET", url, function(response, err)
    if err then
      notify("[reposcope] No response from Codeberg API: " .. err, 4)
      repo_cache_clear()
      on_failure()
      return
    end

    local ok, parsed = pcall(vim.json.decode, response)
    if not ok or not parsed or not parsed.data then
      notify("[reposcope] Invalid or empty Codeberg API response.", 4)
      repo_cache_clear()
      on_failure()
      return
    end

    local data = parsed.data
    local items = {}
    for i = 1, #data do
      items[i] = _normalize(data[i])
    end

    repo_cache_set({ total_count = #items, items = items }, true)
    notify("[reposcope] " .. #items .. " repositories received from Codeberg.", 2)
    vim.schedule(on_success)
  end, nil, "fetch_repositories")
end

return M
