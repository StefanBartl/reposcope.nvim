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
function M.fetch_github_repositories(query)
  if query == "" then
    notify("[reposcope] Error: Search query is empty.", vim.log.levels.ERROR)
    return
  end

  local encoded_query = urlencode(query)
  local url = string.format("https://api.github.com/search/repositories?q=%s", encoded_query)

  api.get(url, function(response)
    if not response then
      notify("[reposcope] No response from GitHub API.", vim.log.levels.ERROR)
      return
    end

    -- Print raw api response
    if debug.options.dev_mode == true then
      --vim.schedule(function()
        --notify("[reposcope] Raw API Response: " .. response, vim.log.levels.DEBUG)
      --end)
    end

    local parsed = vim.json.decode(response)
    if not parsed or not parsed.items then
      notify("[reposcope] Invalid JSON response from GitHub API.", vim.log.levels.ERROR)
      return
    end

    repositories.set_repositories(parsed)
    list.display()
    notify("[reposcope] Loaded repositories from GitHub API.", vim.log.levels.INFO)
  end, nil, nil, "fetch_repositories")
end

return M
