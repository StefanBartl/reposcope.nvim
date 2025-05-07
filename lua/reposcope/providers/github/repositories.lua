---@class RepositoryManager
---@field init fun(query: string, debug?: boolean): nil Initializes the repository list with a query
---@field load_test_json fun(): nil Loads repositories from the test JSON file for debugging
---@field fetch_github_repositories fun(query: string): nil Fetches repositories from GitHub API based on a query
---@field build_cmd fun(query: string): string[] Builds the curl command for GitHub repo search
local M = {}

local repositories = require("reposcope.state.repositories")
local json = require("reposcope.core.json")
local list = require("reposcope.ui.list.repositories")
local config = require("reposcope.config")
local notify = require("reposcope.utils.debug").notify

-- Default path for test JSON
local testjson = "/media/steve/Depot/MyGithub/reposcope.nvim/debug/gh_test_response.json"

-- Default GitHub API version
local GH_API_VERSION = "2022-11-28"

---Initializes the repository list with a query
---@param query string The search query (e.g., "neovim topic:plugin")
---@param debug? boolean If true, loads test JSON instead of making an API request
function M.init(query, debug)
  if debug or config.is_debug_mode() then
    M.load_test_json()
  else
    M.fetch_github_repositories(query)
  end
end

---Loads repositories from the test JSON file for debugging
function M.load_test_json()
  local parsed = json.read_and_parse_file(testjson)
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

---Fetches repositories from GitHub API
---@param query string The search query (e.g., "neovim topic:plugin")
function M.fetch_github_repositories(query)
  local cmd = M.build_cmd(query)
  local handle = io.popen(table.concat(cmd, " "))
  if not handle then
    notify("[reposcope] Failed to start curl process.", vim.log.levels.ERROR)
    return
  end

  local response = handle:read("*a")
  handle:close()

  if not response or response == "" then
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
end

---Builds curl command for GitHub repo search
---@param query string The search query (e.g., "neovim topic:plugin")
---@return string[] The curl command to execute
function M.build_cmd(query)
  local url = "https://api.github.com/search/repositories?q=" .. vim.fn.escape(query, " ")
  return {
    "curl", "-s",
    "-H", "Accept: application/vnd.github+json",
    "-H", "X-GitHub-Api-Version: " .. GH_API_VERSION,
    url
  }
end

return M
