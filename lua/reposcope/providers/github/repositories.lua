---@class GithubRepositories
---@field fetch_repositories fun(query: string, uuid: string): nil Fetches repositories from GitHub API based on a query
---@field build_cmd fun(query: string): string[] Builds the API request for GitHub repo search
local M = {}

-- GitHub API search URL
local GITHUB_API_SEARCH_URL = "https://api.github.com/search/repositories?q=%s"

-- API Client (GitHub API Integration)
local api_client = require("reposcope.network.clients.api_client")
-- Cache Management
local repository_cache = require("reposcope.cache.repository_cache")
-- State Management (Repositories, Requests, UI)
local request_state = require("reposcope.state.requests_state")
local ui_state = require("reposcope.state.ui.ui_state")
-- Controllers (List UI Management)
local list_controller = require("reposcope.controllers.list_controller")
local list_manager = require("reposcope.ui.list.list_manager")
local preview_manager = require("reposcope.ui.preview.preview_manager")
-- Utility Modules (Debugging, Core Utilities, Encoding)
local notify = require("reposcope.utils.debug").notify
local urlencode = require("reposcope.utils.encoding").urlencode


---Builds the full GitHub API URL from a query
---@param query string
---@return string
function M.build_url(query)
  local encoded_query = urlencode(query or "")
  return string.format(GITHUB_API_SEARCH_URL, encoded_query)
end


---Handling of the UI after an API-Error occurs
--- - Clear repositories cache
--- - Clear the list UI
--- - Cleat the preview UI
---@private
---@return nil
local function ui_handle_error()
  vim.schedule(function()
    repository_cache.clear()
    list_manager.clear_list()
    preview_manager.clear_preview()
  end)
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

  api_client.request("GET", url, function(response, err)
    request_state.end_request(uuid)

    if err then
      notify("[reposcope] No response from GitHub API: " .. err, 4)
      ui_handle_error()
      return
    end

    local ok, parsed = pcall(vim.json.decode, response)
    if not ok then
      notify("[reposcope] Invalid JSON response from GitHub API: " .. response, 4)
      ui_handle_error()
      return
    end

    if not parsed or not parsed.items then
      notify("[reposcope] No repositories found in API response.", 4)
      ui_handle_error()
      return
    end

    -- Set repositories in state (cache)
    repository_cache.set(parsed)

    -- Ensure that the list UI is displayed and populated
    vim.schedule(function()
      list_manager.reset_selected_line()
      list_controller.display_repositories()

      -- Wait for the list to be populated before selecting a line
      vim.defer_fn(function()
        if ui_state.buffers.list and vim.api.nvim_buf_is_valid(ui_state.buffers.list) then
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
