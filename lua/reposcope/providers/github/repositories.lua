---@module 'reposcope.providers.github.repositories'
---@brief Fetches and manages GitHub repository search results.
---@description
--- This module is responsible for executing GitHub repository search queries
--- via the GitHub API, decoding and validating the response, and updating the
--- UI state accordingly. It handles caching of results, error management,
--- and populates the list and preview views in the Reposcope UI.

---@class GithubRepositories : GithubRepositoriesModule
local M = {}

local schedule = vim.schedule
local defer_fn = vim.defer_fn
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
-- API Client (GitHub API Integration)
local client_request = require("reposcope.network.clients.api_client").request
-- Cache Management
local repo_cache_set = require("reposcope.cache.repository_cache").set
local repo_cache_clear = require("reposcope.cache.repository_cache").clear
-- State Management (Repositories, Requests, UI)
local request_state = require("reposcope.state.requests_state")
local ui_state = require("reposcope.state.ui.ui_state")
-- Controllers (List UI Management)
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local reset_selected_line = require("reposcope.ui.list.list_manager").reset_selected_line
local clear_list = require("reposcope.ui.list.list_manager").clear_list
local clear_preview = require("reposcope.ui.preview.preview_manager").clear_preview
-- Utility Modules (Debugging, Core Utilities, Encoding)
local notify = require("reposcope.utils.debug").notify
local urlencode = require("reposcope.utils.encoding").urlencode


-- Hardcoded GitHub API search URL
local GITHUB_API_SEARCH_URL = "https://api.github.com/search/repositories?q=%s"

---@private
---Handling of the UI after an API-Error occurs
--- - Clear repositories cache
--- - Clear the list UI
--- - Cleat the preview UI
---@return nil
local function _ui_handle_error()
  schedule(function()
    repo_cache_clear()
    clear_list()
    clear_preview()
  end)
end


---Builds the full GitHub API URL from a query
---@param query string
---@return string
function M.build_url(query)
  local encoded_query = urlencode(query or "")
  return string.format(GITHUB_API_SEARCH_URL, encoded_query)
end


--- Fetches repositories from GitHub API
---@param query string The search query for GitHub repositories
---@param uuid string A unique identifier for this request
function M.fetch_repositories(query, uuid)
  if not request_state.is_registered(uuid) then return end
  if request_state.is_request_active(uuid) then return end
  request_state.start_request(uuid)

  if query == "" then
    notify("[reposcope] Error: Search query is empty.", 4)
    return
  end

  local url = M.build_url(query)

  client_request("GET", url, function(response, err)
    request_state.end_request(uuid)

    if err then
      notify("[reposcope] No response from GitHub API: " .. err, 4)
      _ui_handle_error()
      return
    end

    local ok, parsed = pcall(vim.json.decode, response)
    if not ok then
      notify("[reposcope] Invalid JSON response from GitHub API: " .. response, 4)
      _ui_handle_error()
      return
    end

    if not parsed or not parsed.items then
      notify("[reposcope] No repositories found in API response.", 4)
      _ui_handle_error()
      return
    end

    -- Set repositories in state (cache)
    repo_cache_set(parsed)

    -- Ensure that the list UI is displayed and populated
    schedule(function()
      reset_selected_line()
      display_repositories()

      -- Wait for the list to be populated before selecting a line
      defer_fn(function()
        if ui_state.buffers.list and nvim_buf_is_valid(ui_state.buffers.list) then
          ui_state.list.last_selected_line = 1 -- Default to the first line
          notify("[reposcope] Default list line set to first entry.", 2)

          -- Automatically load README for the first in the result list
          require("reposcope.controllers.provider_controller").fetch_readme_for_selected()
        else
          notify("[reposcope] List buffer is not available. README fetch canceled.", 4)
        end
      end, 100) -- Delay slightly to ensure list is displayed
    end)
  end, nil, "fetch_repositories")
end

return M
