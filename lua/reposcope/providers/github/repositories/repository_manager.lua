---@module 'reposcope.providers.github.repositories.repository_manager'
---@brief Coordinates repository fetching and UI update after search.
---@description
---This module combines the logic of fetching repositories from GitHub
--- and updating the user interface once results are received.
--- It delegates API and UI responsibilities to their respective modules:
--- - `repository_fetcher` handles network calls and cache updates
--- - `repository_ui_loader` initializes the UI display
---
---All repository fetch calls must go through this manager to ensure
--- proper lifecycle tracking via UUIDs and `request_state`. This ensures
--- that requests are not duplicated and are tracked cleanly.
--- The manager performs UUID validation, request registration, and
--- fallback handling on failure.

---@class GithubRepositoryManager : GithubRepositoryManagerModule
local M = {}

-- Submodules
local fetcher = require("reposcope.providers.github.repositories.repository_fetcher")
local ui_loader = require("reposcope.providers.github.repositories.repository_ui_loader")
-- State & Utilities
local request_state = require("reposcope.state.requests_state")
local notify = require("reposcope.utils.debug").notify
local clear_list = require("reposcope.ui.list.list_manager").clear_list
local clear_preview = require("reposcope.ui.preview.preview_manager").clear_preview
local repo_cache_clear = require("reposcope.cache.repository_cache").clear


---Handles clearing UI and state in case of API or fetch errors
---@private
---@return nil
local function _handle_fetch_failure()
  repo_cache_clear()
  clear_list()
  clear_preview()
end


---Fetches GitHub repositories without UI logic (for headless or cache-only usage)
---@param query string
---@param uuid string
---@param on_success? fun(): nil
---@param on_failure? fun(): nil
---@return nil
function M.fetch(query, uuid, on_success, on_failure)
  if not request_state.is_registered(uuid) then
    notify("[reposcope] Skipped fetch: UUID not registered", 3)
    return
  end
  if request_state.is_request_active(uuid) then
    notify("[reposcope] Skipped fetch: Request already active for UUID " .. uuid, 3)
    return
  end

  request_state.start_request(uuid)

  fetcher.fetch_repositories(query, function()
    if on_success then on_success() end
  end, function()
    if on_failure then
      on_failure()
    else
      _handle_fetch_failure()
    end
  end)
end


---@param query string
---@param uuid string
---@param on_failure? fun(): nil
function M.fetch_and_display(query, uuid, on_failure)
  if not request_state.is_registered(uuid) then
    notify("[reposcope] Skipped fetch: UUID not registered", 3)
    return
  end
  if request_state.is_request_active(uuid) then
    notify("[reposcope] Skipped fetch: Request already active for UUID " .. uuid, 3)
    return
  end

  request_state.start_request(uuid)

  fetcher.fetch_repositories(query, function()
    ui_loader.load_ui_after_fetch()
  end, function()
    if on_failure then
      on_failure()
    else
      _handle_fetch_failure()
    end
  end)
end

return M
