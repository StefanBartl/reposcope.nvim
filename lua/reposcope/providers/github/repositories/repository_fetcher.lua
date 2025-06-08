---@module 'reposcope.providers.github.repositories.repository_fetcher'
---@brief Fetches repositories from the GitHub API and updates the local cache.
---@description
--- This module is responsible for building the GitHub API request URL,
--- sending the repository search request, decoding the response,
--- and storing the result in the internal repository cache.
--- It does not interact with the user interface or trigger list updates.

---@class GithubRepositoryFetcher : GithubRepositoryFetcherModule
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
local GITHUB_API_SEARCH_URL = "https://api.github.com/search/repositories?q=%s"


---Builds the full GitHub API URL from a query
---@param query string
---@return string
function M.build_url(query)
  local encoded_query = urlencode(query or "")
  return string.format(GITHUB_API_SEARCH_URL, encoded_query)
end

--- Fetches repositories from GitHub API and updates the repository cache
---@param query string The search query for GitHub repositories
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
      notify("[reposcope] No response from GitHub API: " .. err, 4)
      repo_cache_clear()
      on_failure()
      return
    end

    local ok, parsed = pcall(vim.json.decode, response)
    if not ok or not parsed or not parsed.items then
      notify("[reposcope] Invalid or empty GitHub API response.", 4)
      repo_cache_clear()
      on_failure()
      return
    end

    repo_cache_set(parsed, true)
    notify("[reposcope] " .. #parsed.items or 0 .. " repositories received from GitHub.", 2)
    vim.schedule(on_success)
  end, nil, "fetch_repositories")
end

return M
