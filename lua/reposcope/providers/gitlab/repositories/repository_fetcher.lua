---@module 'reposcope.providers.gitlab.repositories.repository_fetcher'
---@brief Fetches repositories from the GitLab API and updates the local cache.
---@description
--- This module is responsible for building the GitLab API request URL,
--- sending the project search request, decoding the response, normalizing
--- GitLab's project JSON into the shared `Repository` shape, and storing the
--- result in the internal repository cache. It does not interact with the
--- user interface.
---
--- GitLab's `/projects` search response is a flat JSON array (no wrapping
--- object, no `total_count`), unlike GitHub's `{total_count, items}` shape —
--- `total_count` is approximated as the number of items actually returned.

---@class GitlabRepositoryFetcher : RepositoryFetcherModule
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
local GITLAB_API_SEARCH_URL = "https://gitlab.com/api/v4/projects?search=%s&order_by=star_count&sort=desc"


---Builds the full GitLab API URL from a query
---@param query string
---@return string
function M.build_url(query)
  local encoded_query = urlencode(query or "")
  return string.format(GITLAB_API_SEARCH_URL, encoded_query)
end


---@private
---Normalizes a single GitLab project object into the shared `Repository` shape
---@param project table
---@return Repository
local function _normalize(project)
  return {
    name = project.path,
    description = project.description or "",
    -- `.git`-suffixed clone URL (not `web_url`) so clone_command.lua can
    -- reliably parse owner/repo back out of it for zip-archive downloads
    html_url = project.http_url_to_repo or project.web_url,
    owner = { login = project.namespace and project.namespace.path or "" },
    default_branch = project.default_branch,
    stargazers_count = project.star_count,
  }
end


--- Fetches repositories from the GitLab API and updates the repository cache
---@param query string The search query for GitLab projects
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
      notify("[reposcope] No response from GitLab API: " .. err, 4)
      repo_cache_clear()
      on_failure()
      return
    end

    local ok, parsed = pcall(vim.json.decode, response)
    if not ok or type(parsed) ~= "table" then
      notify("[reposcope] Invalid or empty GitLab API response.", 4)
      repo_cache_clear()
      on_failure()
      return
    end

    local items = {}
    for i = 1, #parsed do
      items[i] = _normalize(parsed[i])
    end

    repo_cache_set({ total_count = #items, items = items }, true)
    notify("[reposcope] " .. #items .. " repositories received from GitLab.", 2)
    vim.schedule(on_success)
  end, nil, "fetch_repositories")
end

return M
