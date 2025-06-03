---@module 'reposcope.providers.github.readme.readme_manager'
---@brief Controls fetching and caching of repository README files
---@description
--- This module coordinates the download and caching of README files using
--- the readme_fetcher module. It checks for cached data and handles UI updates
--- after successfully retrieving README content, either from RAM, file, or network.

---@class ReadmeManager : ReadmeManagerModule
local M = {}

-- Vim Utilities
local schedule = vim.schedule
-- Debugging and Utilities
local notify = require("reposcope.utils.debug").notify
local generate_uuid = require("reposcope.utils.core").generate_uuid
local metrics = require("reposcope.utils.metrics")
local request_state = require("reposcope.state.requests_state")
-- Readme Utilities and Cache
local readme_fetch_api = require("reposcope.providers.github.readme.readme_fetcher").fetch_api
local readme_fetch_raw = require("reposcope.providers.github.readme.readme_fetcher").fetch_raw
local set_ram = require("reposcope.cache.readme_cache").set_ram
local set_file = require("reposcope.cache.readme_cache").set_file
local has = require("reposcope.cache.readme_cache").has
local get_selected_repo = require("reposcope.cache.repository_cache").get_selected
-- UI related
local update_preview = require("reposcope.ui.preview.preview_manager").update_preview


---@private
---@param owner string
---@param repo_name string
---@param branch string
---@param uuid string
---@return nil
local function _fetch_from_api_fallback(owner, repo_name, branch, uuid)
  readme_fetch_api(owner, repo_name, branch, function(success, content, err)
    if not success or not content then
      notify("[reposcope] API fetch failed: " .. (err or "unknown error"), 4)
      return
    end

    schedule(function()
      set_ram(repo_name, content)
      set_file(repo_name, content)
      update_preview(repo_name)
      request_state.end_request(uuid)
    end)
  end)
end

---@private
---@param repo table
---@param repo_name string
---@return nil
local function _record_metrics(repo, repo_name)
  local uuid = generate_uuid()
  local ok, source = has(repo_name)

  if not ok or not metrics.record_metrics() then
    return
  end

  if source == "ram" then
    metrics.increase_cache_hit(uuid, repo_name, repo.html_url, "readme_manager")
  elseif source == "file" then
    metrics.increase_fcache_hit(uuid, repo_name, repo.html_url, "readme_manager")
  end
end

---Fetches the README for the currently selected repository
---@param uuid string
---@return nil
function M.fetch_for_selected(uuid)
  if not request_state.is_registered(uuid) then return end
  if request_state.is_request_active(uuid) then return end
  request_state.start_request(uuid)

  local repo = get_selected_repo()
  if not repo or not repo.name or not repo.owner or not repo.owner.login then
    notify("[reposcope] Invalid repository selection", 4)
    return
  end

  local owner = repo.owner.login
  local repo_name = repo.name
  local branch = repo.default_branch or "main"

  if has(repo_name) then
    _record_metrics(repo, repo_name)
    schedule(function()
      update_preview(repo_name)
    end)
    return
  end

  readme_fetch_raw(owner, repo_name, branch, function(success, content, err)
    if success and content then
      schedule(function()
        set_ram(repo_name, content)
        set_file(repo_name, content)
        update_preview(repo_name)
        request_state.end_request(uuid)
      end)
    else
      notify("[reposcope] Raw fetch failed: " .. (err or "unknown error"), vim.log.levels.WARN)
      _fetch_from_api_fallback(owner, repo_name, branch, uuid)
    end
  end)
end

return M
