---@module 'reposcope.providers.github.readme.readme_manager'
---@brief Controls fetching and caching of repository README files
---@description
--- This module coordinates the download and caching of README files using
--- the readme_fetcher module. It checks for cached data and handles UI updates
--- after successfully retrieving README content, either from RAM, file, or network.
---
---All readme fetch calls must go through this manager to ensure
--- proper lifecycle tracking via UUIDs and `request_state`. This ensures
--- that requests are not duplicated and are tracked cleanly.
--- The manager performs UUID validation, request registration, and
--- fallback handling on failure.

---@class ReadmeManager : ReadmeManagerModule
local M = {}

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
local set_updated_at = require("reposcope.cache.readme_cache").set_updated_at
local has = require("reposcope.cache.readme_cache").has
local has_fresh = require("reposcope.cache.readme_cache").has_fresh
local get_selected_repo = require("reposcope.cache.repository_cache").get_selected
-- UI related
local update_preview = require("reposcope.ui.preview.preview_manager").update_preview
local inject_content = require("reposcope.ui.preview.preview_manager").inject_content
local clear_preview = require("reposcope.ui.preview.preview_manager").clear_preview
local ui_state = require("reposcope.state.ui.ui_state")

---@private
---@internal
---@param owner string
---@param repo_name string
---@param branch string
---@param uuid string
---@param updated_at string|nil
---@return boolean
local function _fetch_from_api_fallback(owner, repo_name, branch, uuid, updated_at)
  readme_fetch_api(owner, repo_name, branch, function(success, content, err)
    if not success or not content then
      notify("[reposcope] API fetch failed: " .. (err or "unknown error"), 4)
      return false
    end

    vim.schedule(function()
      set_ram(owner, repo_name, content)
      set_file(owner, repo_name, content)
      set_updated_at(owner, repo_name, updated_at)
      update_preview(owner, repo_name)
      request_state.end_request(uuid)
    end)
  end)

  return true
end

---@private
---@internal
---@param repo Repository
---@param owner string
---@param repo_name string
---@return nil
local function _record_metrics(repo, owner, repo_name)
  local uuid = generate_uuid()
  local ok, source = has(owner, repo_name)

  if not ok or not metrics.record_metrics() then return end

  if source == "ram" then
    metrics.increase_cache_hit(uuid, repo_name, source, "readme_manager", repo.html_url)
  elseif source == "file" then
    metrics.increase_fcache_hit(uuid, repo_name, source, "readme_manager", repo.html_url)
  end
end

---@private
---@internal
---Checks whether a string looks like an `http(s)://` URL.
---@param url string
---@return boolean
local function is_valid_url(url) return type(url) == "string" and url:match("^https?://") end

---Fetches and caches (RAM + file) `repo`'s README in the background, without
--- touching the preview window or `request_state` — for pre-caching upcoming
--- list entries (`repository_ui_loader`'s post-search warm-up), not the
--- current selection. No-op if already fresh, or if the raw fetch fails
--- (silent: this is a background optimization, not a user-facing action —
--- a normal fetch still happens if/when the repository is actually selected).
---@param repo Repository
---@return nil
function M.prefetch(repo)
  if not repo or not repo.name or not repo.owner or not repo.owner.login then return end

  local owner = repo.owner.login
  local repo_name = repo.name
  local branch = repo.default_branch or "main"

  if has_fresh(owner, repo_name, repo.updated_at) then return end

  local urls = require("reposcope.providers.github.readme.readme_urls").get_urls(owner, repo_name, branch)
  if not is_valid_url(urls.raw) then return end

  readme_fetch_raw(owner, repo_name, branch, function(success, content)
    if success and content then
      vim.schedule(function()
        set_ram(owner, repo_name, content)
        set_file(owner, repo_name, content)
        set_updated_at(owner, repo_name, repo.updated_at)
      end)
    end
  end)
end

---Fetches the README for the currently selected repository
---@param uuid string
---@return nil
---@see reposcope.providers.codeberg.readme.readme_manager.M.fetch_for_selected, reposcope.providers.gitlab.readme.readme_manager.M.fetch_for_selected
function M.fetch_for_selected(uuid)
  if not request_state.is_registered(uuid) then return end
  if request_state.is_request_active(uuid) then return end
  request_state.start_request(uuid)

  local repo = get_selected_repo()
  if not repo or not repo.name or not repo.owner or not repo.owner.login then
    request_state.end_request(uuid)
    vim.schedule(function() require("reposcope.ui.preview.preview_manager").clear_preview() end)
    return
  end

  local owner = repo.owner.login
  local repo_name = repo.name
  local branch = repo.default_branch or "main"

  local urls = require("reposcope.providers.github.readme.readme_urls").get_urls(owner, repo_name, branch)

  if not is_valid_url(urls.raw) then
    request_state.end_request(uuid)
    vim.schedule(function() require("reposcope.ui.preview.preview_manager").clear_preview() end)
    return
  end

  if has_fresh(owner, repo_name, repo.updated_at) then
    _record_metrics(repo, owner, repo_name)
    vim.schedule(function() update_preview(owner, repo_name) end)
    return
  end

  readme_fetch_raw(owner, repo_name, branch, function(success, content, err)
    if success and content then
      vim.schedule(function()
        set_ram(owner, repo_name, content)
        set_file(owner, repo_name, content)
        set_updated_at(owner, repo_name, repo.updated_at)
        update_preview(owner, repo_name)
        request_state.end_request(uuid)
      end)
    else
      notify("[reposcope] Raw fetch failed: " .. (err or "unknown error"), vim.log.levels.WARN)
      if not _fetch_from_api_fallback(owner, repo_name, branch, uuid, repo.updated_at) then
        -- If neither readme raw or api fetch was valid, let user know README is not available
        local buf = ui_state.buffers.preview
        if not buf then
          clear_preview()
          notify("[reposcope] README couldn't be fetched. Preview window cleared.")
        else
          local lines = "README from this repository couldn't be fetched."
          inject_content(buf, { lines }, "text")
          notify("[reposcope] README couldn't be fetched. User message in preview window.")
        end
      end
    end
  end)
end

return M
