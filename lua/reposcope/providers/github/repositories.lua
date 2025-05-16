---@class RepositoryManager
---@field init fun(query: string, debug?: boolean): nil Initializes the repository list with a query
---@field load_test_json fun(): nil Loads repositories from the test JSON file for debugging
---@field fetch_github_repositories fun(query: string, uuid: string): nil Fetches repositories from GitHub API based on a query
---@field build_cmd fun(query: string): string[] Builds the API request for GitHub repo search
local M = {}

local api = require("reposcope.network.api")
local repos_state = require("reposcope.state.repositories")
local req_state = require("reposcope.state.requests")
local list = require("reposcope.ui.list.repositories")
local debug = require("reposcope.utils.debug")
local core_utils = require("reposcope.utils.core")
local urlencode = require("reposcope.network.http").urlencode
local metrics = require("reposcope.utils.metrics")

--- Initializes the repository list with a query
function M.init(query)
  local uuid = metrics.generate_uuid()
  table.insert(req_state.repositories, uuid)

  M.fetch_github_repositories(query, uuid)
end

--- Fetches repositories from GitHub API
function M.fetch_github_repositories(query, uuid)
  local check = core_utils.tbl_find(req_state.repositories, uuid)
  if not check then
    debug.notify("not passed uuid check: " .. uuid .. " with query: " .. query, 4)
    return
  else
    debug.notify("uuid check passed: " .. uuid .. " with query: " .. query, 1)
  end

  if query == "" then
    debug.notify("[reposcope] Error: Search query is empty.", 4)
    return
  end

  local encoded_query = urlencode(query)
  local url = string.format("https://api.github.com/search/repositories?q=%s", encoded_query)
  local start_time = vim.loop.hrtime()

  api.get(url, function(response)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- from nano to mills

    if not response then
      if metrics.record_metrics() then
        metrics.increase_failed(uuid, query, "search_api", "fetch_repositories", duration_ms, 0, "No response")
      end
      debug.notify("[reposcope] No response from GitHub API.", 4)
      return
    end

    local parsed = vim.json.decode(response)
    if not parsed or not parsed.items then
      if metrics.record_metrics() then
        metrics.increase_failed(uuid, query, "search_api", "fetch_repositories", duration_ms, 0, "Invalid JSON")
      end
      debug.notify("[reposcope] Invalid JSON response from GitHub API.", 4)
      return
    end

    print("Increase success - API success")
    if metrics.record_metrics() then
      metrics.increase_success(uuid, query, "search_api", "fetch_repositories", duration_ms, 200)
    end
    repos_state.set_repositories(parsed)
    list.display()
    vim.schedule(function()
      require("reposcope.providers.github.readme").fetch_readme_for_selected()
    end)
    debug.notify("[reposcope] Loaded repositories from GitHub API.", 2)
  end)
end

return M
