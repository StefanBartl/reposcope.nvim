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

-- Shown in the preview when a repository has no README we can reach. Plenty of
-- repositories simply do not carry one, so this is an ordinary outcome of
-- walking the list — not an error worth a message of its own.
local UNAVAILABLE_MSG = "README from this repository couldn't be fetched."

---@private
---@internal
---Puts `UNAVAILABLE_MSG` in the preview, but only while `owner/repo_name` is
--- still the selected entry: a fetch that fails after the user has already
--- moved on must not paint over the README of whatever they moved to.
---@param owner string
---@param repo_name string
---@return nil
local function _show_unavailable(owner, repo_name)
  local selected = get_selected_repo()
  if not selected or selected.name ~= repo_name then return end
  if not selected.owner or selected.owner.login ~= owner then return end

  local buf = ui_state.buffers.preview
  if not buf then return end

  clear_preview() -- Drops a drawn README image along with the old text
  inject_content(buf, { UNAVAILABLE_MSG }, "text")
end

---@private
---@internal
---@param owner string
---@param repo_name string
---@param branch string
---@param uuid string
---@param updated_at string|nil
---@return nil
local function _fetch_from_api(owner, repo_name, branch, uuid, updated_at)
  readme_fetch_api(owner, repo_name, branch, function(success, content, err)
    if not success or not content then
      notify("[reposcope] API README fetch failed for " .. owner .. "/" .. repo_name .. ": " .. (err or "not found"), 2)
      request_state.end_request(uuid)
      vim.schedule(function() _show_unavailable(owner, repo_name) end)
      return
    end

    vim.schedule(function()
      set_ram(owner, repo_name, content)
      set_file(owner, repo_name, content)
      set_updated_at(owner, repo_name, updated_at)
      update_preview(owner, repo_name)
      request_state.end_request(uuid)
    end)
  end)
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

---@private
---@internal
---Whether `repo`'s README has to be fetched through the API rather than the
--- raw host. `raw.githubusercontent.com` answers 404 for a private repository
--- even when the request carries credentials — it does not honor them the way
--- `api.github.com` does — so for those the raw attempt is a process spawn
--- that cannot succeed, paid on every list step. The API is the only path that
--- works, so take it directly.
---@param repo Repository
---@return boolean
local function needs_api(repo) return repo.private == true end

---Fetches and caches (RAM + file) `repo`'s README in the background, without
--- touching the preview window or `request_state` — for pre-caching upcoming
--- list entries (`repository_ui_loader`'s post-search warm-up), not the
--- current selection. No-op if already fresh, or if the fetch fails
--- (silent: this is a background optimization, not a user-facing action —
--- a normal fetch still happens if/when the repository is actually selected).
---
---One request per repository, deliberately: no raw-then-API retry, since the
--- point is to be cheap. Private repositories go to the API instead of the raw
--- host rather than in addition to it (see `needs_api`) — before that they
--- were never pre-cached at all, because the only request they made was the
--- one that always 404s.
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

  local function store(success, content)
    if not success or not content then return end
    vim.schedule(function()
      set_ram(owner, repo_name, content)
      set_file(owner, repo_name, content)
      set_updated_at(owner, repo_name, repo.updated_at)
    end)
  end

  if needs_api(repo) then
    readme_fetch_api(owner, repo_name, branch, store)
  else
    readme_fetch_raw(owner, repo_name, branch, store)
  end
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
    request_state.end_request(uuid)
    vim.schedule(function() update_preview(owner, repo_name) end)
    return
  end

  if needs_api(repo) then
    _fetch_from_api(owner, repo_name, branch, uuid, repo.updated_at)
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
      -- A missing README.md on `branch` is the common case here, not a fault:
      -- report it to dev mode only and let the API fallback have its turn. It
      -- is the fallback that decides whether the user sees anything.
      notify("[reposcope] Raw README fetch failed for " .. owner .. "/" .. repo_name .. ": " .. (err or "not found"), 2)
      _fetch_from_api(owner, repo_name, branch, uuid, repo.updated_at)
    end
  end)
end

return M
