---@class RepositoryManager
---@field init fun(query: string, debug?: boolean): nil Initializes the repository list with a query
---@field load_test_json fun(): nil Loads repositories from the test JSON file for debugging
---@field fetch_github_repositories fun(query: string): nil Fetches repositories from GitHub API based on a query
---@field build_cmd fun(query: string): string[] Builds the API request for GitHub repo search
local M = {}

local api = require("reposcope.network.api")
local repositories = require("reposcope.state.repositories")
local list = require("reposcope.ui.list.repositories")
local debug = require("reposcope.utils.debug")
local notify = debug.notify
local urlencode = require("reposcope.network.http").urlencode

--- Initializes the repository list with a query
function M.init(query)
    M.fetch_github_repositories(query)
end

--- Fetches repositories from GitHub API
--- Fetches repositories from GitHub API
function M.fetch_github_repositories(query)
  if query == "" then
    notify("[reposcope] Error: Search query is empty.", 4)
    return
  end

  local metrics = require("reposcope.utils.metrics")
  local encoded_query = urlencode(query)
  local url = string.format("https://api.github.com/search/repositories?q=%s", encoded_query)
  local uuid = metrics.generate_uuid()
  local start_time = vim.loop.hrtime()

  api.get(url, function(response)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- from nano to mills

    if not response then
      print("Increase failed - No response")
      metrics.increase_failed(uuid, query, "search_api", "fetch_repositories", duration_ms, 0, "No response")
      notify("[reposcope] No response from GitHub API.", 4)
      return
    end

    local parsed = vim.json.decode(response)
    if not parsed or not parsed.items then
      print("Increase failed - Invalid JSON")
      metrics.increase_failed(uuid, query, "search_api", "fetch_repositories", duration_ms, 0, "Invalid JSON")
      notify("[reposcope] Invalid JSON response from GitHub API.", 4)
      return
    end

    print("Increase success - API success")
    metrics.increase_success(uuid, query, "search_api", "fetch_repositories", duration_ms, 200)
    repositories.set_repositories(parsed)
    list.display()
    vim.schedule(function()
      require("reposcope.providers.github.readme").fetch_readme_for_selected()
    end)
    notify("[reposcope] Loaded repositories from GitHub API.", 2)
  end)
end


return M
