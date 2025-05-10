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

-- Default path for test JSON
local testjson = "/media/steve/Depot/MyGithub/reposcope.nvim/debug/gh_test_response.json"

--- Initializes the repository list with a query
function M.init(query, debug_mode)
  if debug_mode or debug.is_debug_mode() then
    M.load_test_json()
  else
    M.fetch_github_repositories(query)
  end
end

--- Loads repositories from the test JSON file for debugging
function M.load_test_json()
  local parsed = require("reposcope.core.json").read_and_parse_file(testjson)
  if not parsed then
    notify("[reposcope] Failed to load test JSON", vim.log.levels.ERROR)
    return
  end

  if not parsed.items then
    notify("[reposcope] Invalid JSON format in test file.", vim.log.levels.ERROR)
    return
  end

  repositories.set_repositories(parsed)
  list.display()
  notify("[reposcope] Loaded test JSON data.", vim.log.levels.INFO)
end

--- Fetches repositories from GitHub API
function M.fetch_github_repositories(query)
  local url = string.format("https://api.github.com/search/repositories?q=%s", vim.fn.escape(query, " "))
  api.get(url, function(response)
    if not response then
      notify("[reposcope] No response from GitHub API.", vim.log.levels.ERROR)
      return
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
