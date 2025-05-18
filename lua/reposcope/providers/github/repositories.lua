---@class GithubRepositories
---@field init fun(query: string, debug?: boolean): nil Initializes the repository list with a query
---@field load_test_json fun(): nil Loads repositories from the test JSON file for debugging
---@field fetch_github_repositories fun(query: string, uuid: string): nil Fetches repositories from GitHub API based on a query
---@field build_cmd fun(query: string): string[] Builds the API request for GitHub repo search
local M = {}

-- GitHub API search URL
local GITHUB_API_SEARCH_URL = "https://api.github.com/search/repositories?q=%s"

local api_client = require("reposcope.network.clients.api_client")
local repos_state = require("reposcope.state.repositories")
local req_state = require("reposcope.state.requests")
local list = require("reposcope.ui.list.repositories")
local debug = require("reposcope.utils.debug")
local core_utils = require("reposcope.utils.core")
local urlencode = require("reposcope.utils.encoding").urlencode

--- Initializes the repository list with a query
---@param query string The search query for GitHub repositories
function M.init(query)
  local uuid = vim.fn.system("uuidgen"):gsub("\n", "")
  table.insert(req_state.repositories, uuid)

  M.fetch_github_repositories(query, uuid)
end

--- Fetches repositories from GitHub API
---@param query string The search query for GitHub repositories
---@param uuid string A unique identifier for this request
function M.fetch_github_repositories(query, uuid)
  -- Validate UUID
  local check = core_utils.tbl_find(req_state.repositories, uuid)
  if not check then
    debug.notify("UUID check failed: " .. uuid .. " with query: " .. query, 4)
    return
  else
    debug.notify("UUID check passed: " .. uuid .. " with query: " .. query, 1)
  end

  if query == "" then
    debug.notify("[reposcope] Error: Search query is empty.", 4)
    return
  end

  local encoded_query = urlencode(query)
  local url = string.format(GITHUB_API_SEARCH_URL, encoded_query) -- Using the centralized URL

  api_client.request("GET", url, function(response, err)
    if err then
      debug.notify("[reposcope] No response from GitHub API: " .. err, 4)
      return
    end

    local ok, parsed = pcall(vim.json.decode, response)
    if not ok then
      debug.notify("[reposcope] Invalid JSON response from GitHub API: " .. response, 4)
      return
    end

    if not parsed or not parsed.items then
      debug.notify("[reposcope] No repositories found in API response.", 4)
      return
    end

    repos_state.set_repositories(parsed)
    list.display()

    -- Automatically load README for the selected repository
    vim.schedule(function()
      require("reposcope.providers.github.readme").fetch_readme_for_selected()
    end)
    debug.notify("[reposcope] Loaded repositories from GitHub API.", 2)
  end, nil, false, "fetch_repositories")
end

return M
