---@class ReadmeManager
---@brief Controls fetching and caching of repository README files
---@description
--- This module coordinates the download and caching of README files using
--- the readme_fetcher module. It checks for cached data and handles UI updates
--- after successfully retrieving README content, either from RAM, file, or network.
---@field fetch_for_selected fun(): nil Fetches the README for the currently selected repository
local M = {}

---@description Forward declarations for private functions
local _record_metrics, fetch_from_api_fallback

-- Debugging and Utilities
local notify = require("reposcope.utils.debug").notify
local generate_uuid = require("reposcope.utils.core").generate_uuid
local record_metrics = require("reposcope.utils.metrics").record_metrics
local increase_cache_hit = require("reposcope.utils.metrics").increase_cache_hit
local increase_fcache_hit = require("reposcope.utils.metrics").increase_fcache_hit
-- Readme Utilities and Cache
local readme_fetch_api = require("reposcope.providers.github.readme.readme_fetcher").fetch_api
local readme_fetch_raw = require("reposcope.providers.github.readme.readme_fetcher").fetch_raw
local has_cached_readme = require("reposcope.cache.readme_cache").has_cached_readme
local get_selected_repo = require("reposcope.state.repositories.repositories_state").get_selected_repo
local cache_and_show_readme = require("reposcope.cache.cache_manager").cache_and_show_readme
-- UI related
local update_preview = require("reposcope.ui.preview.preview_manager").update_preview


-- Active requests tracker to avoid duplicate fetches
local active_readme_requests = {}


--- Fetches the README for the currently selected repository
---@return nil
function M.fetch_for_selected()
  local repo = get_selected_repo()
  if not repo or not repo.name or not repo.owner or not repo.owner.login then
    notify("[reposcope] Invalid repository selection", 4)
    return
  end

  local owner = repo.owner.login
  local repo_name = repo.name
  local branch = repo.default_branch or "main"

  if active_readme_requests[repo_name] then return end
  if has_cached_readme(repo_name) then
    _record_metrics(repo, repo_name)
    vim.schedule(function()
      update_preview(repo_name)
    end)
    return
  end

  active_readme_requests[repo_name] = true

  readme_fetch_raw(owner, repo_name, branch, function(success, content, err)
    if success and content then
      vim.schedule(function()
        cache_and_show_readme(repo_name, content)
        active_readme_requests[repo_name] = nil
      end)
    else
      notify("[reposcope] Raw fetch failed: " .. (err or "unknown error"), 3)
      fetch_from_api_fallback(owner, repo_name, branch)
    end
  end)
end


---@private
---@param owner string
---@param repo_name string
---@param branch string
---@return nil
function fetch_from_api_fallback(owner, repo_name, branch)
  readme_fetch_api(owner, repo_name, branch, function(success, content, err)
    active_readme_requests[repo_name] = nil

    if not success or not content then
      notify("[reposcope] API fetch failed: " .. (err or "unknown error"), 4)
      return
    end

    vim.schedule(function()
      cache_and_show_readme(repo_name, content)
    end)
  end)
end


---@private
---@param repo table
---@param repo_name string
---@return nil
function _record_metrics(repo, repo_name)
  local uuid = generate_uuid()
  local ok, source = has_cached_readme(repo_name)

  if not ok or not record_metrics() then
    return
  end

  if source == "ram" then
    increase_cache_hit(uuid, repo_name, repo.html_url, "readme_manager")
  elseif source == "file" then
    increase_fcache_hit(uuid, repo_name, repo.html_url, "readme_manager")
  end
end

return M
