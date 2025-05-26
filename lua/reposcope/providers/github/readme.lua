---@class GithubReadme
---@field fetch_readme_for_selected fun(): nil Initiates the README fetch for the currently selected repository
---@field get_readme_urls fun(owner: string, repo_name: string, branch: string): string, string Constructs the RAW and API URLs for the README
---@field try_fetch_readme fun(raw_url: string, api_url: string, repo_name: string): nil Attempts to fetch the README using the RAW URL, then the API as fallback
---@field fetch_readme_from_api fun(api_url: string, repo_name: string): nil Fetches the README using the GitHub API (fallback)
local M = {}

-- API Client (GitHub API Integration)
local api_client = require("reposcope.network.clients.api_client")
-- Utility Modules (Metrics, Core Utilities, Encoding)
local metrics = require("reposcope.utils.metrics")
local core_utils = require("reposcope.utils.core")
local encoding = require("reposcope.utils.encoding")
-- Cache Management (Readme Cache)
local readme_cache = require("reposcope.cache.readme_cache")
local cache = require("reposcope.cache.cache_manager")
-- State Management (Repositories)
local repositories_state = require("reposcope.state.repositories.repositories_state")
-- UI Components (Preview Injection)
local preview_manager = require("reposcope.ui.preview.preview_manager")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


local active_readme_requests = {}

---Initiates the README fetch for the currently selected repository
---param NOTE: add params and return annotations
function M.fetch_readme_for_selected()
---REF: Refactore this part to a funtion which doesnt gave nil back
  local repo = repositories_state.get_selected_repo()
  if not repo then
    notify("[reposcope] No repository selected", 3)
    return
  end

  local owner = repo.owner and repo.owner.login
  local repo_name = repo.name
  local default_branch = repo.default_branch or "main"

  if not owner or not repo_name then
    notify("[reposcope] Invalid repository URL", 4)
    return
  end

  -- Check if README is already being fetched --REF: cache 
  if active_readme_requests[repo_name] then
    local is_cached, source = readme_cache.has_cached_readme(repo_name)
    if is_cached then
      local uuid = core_utils.generate_uuid()
      if metrics.record_metrics() then  -- REF: should this be in update_readme ? at this point, where it actually uses the cache
        if source == "ram" then
          metrics.increase_cache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
        elseif source == "file" then
          metrics.increase_fcache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
        end
      end
      preview_manager.update_preview(repo_name)
      return
    end
    return
  end

  active_readme_requests[repo_name] = true

  -- Check if README is cached (RAM or File) REF:  cache
  local is_cached, source = readme_cache.has_cached_readme(repo_name)
  if is_cached then
    local uuid = core_utils.generate_uuid()  -- REF: maybe in update_preview()
    if metrics.record_metrics() then
      if source == "ram" then
        metrics.increase_cache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
      elseif source == "file" then
        metrics.increase_fcache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
      end
    end
    preview_manager.update_preview(repo_name)
    active_readme_requests[repo_name] = nil
    return
  end

  local raw_url, api_url = M.get_readme_urls(owner, repo_name, default_branch)
  M.try_fetch_readme(raw_url, api_url, repo_name)
end

--- Attempts to fetch the README using the RAW URL, then the API as fallback
---@param raw_url string The URL for the raw README (GitHub)
---@param api_url string The URL for the GitHub API README (as fallback)
---@param repo_name string The name of the repository
function M.try_fetch_readme(raw_url, api_url, repo_name)
  api_client.request("GET", raw_url, function(response, error)
    if error then
      notify("[reposcope] Error fetching data: " .. error, 4)
      return
    end

    if response then
      cache.cache_and_show_readme(repo_name, response)
    else
      notify("[reposcope] Failed to fetch README from RAW URL. Trying API...", 2)
      M.fetch_readme_from_api(api_url, repo_name)
    end
 end, nil, "fetch_readme")
end

--- Fetches the README using the GitHub API (fallback)
---@param api_url string The API URL for the README file
---@param repo_name string The name of the GitHub repository
function M.fetch_readme_from_api(api_url, repo_name)
  api_client.request("GET", api_url, function(response, err)
    if err then
      notify("[reposcope] Failed to fetch README via API: " .. err, 4)
      return
    end

    -- Check for response
    if not response then
      notify("[reposcope] No response received from API: " .. api_url, 4)
      return
    end

    -- Decode API response (JSON format)
    local decoded = vim.json.decode(response)
    if not decoded or not decoded.content then
      notify("[reposcope] Invalid API response for README", 4)
      return
    end

    -- Decode the Base64-encoded README content using the utility function
    local content = encoding.decode_base64(decoded.content)
    cache.cache_and_show_readme(repo_name, content)
  end, nil, "fetch_readme_api")
end

--- Constructs the RAW and API URLs for the README
---@param owner string The owner of the GitHub repository
---@param repo_name string The name of the GitHub repository
---@param branch string The branch to fetch the README from (e.g., "main")
---@return string, string The RAW URL and the API URL for the README
function M.get_readme_urls(owner, repo_name, branch)
  local raw_url = string.format("https://raw.githubusercontent.com/%s/%s/%s/README.md", owner, repo_name, branch)
  local api_url = string.format("https://api.github.com/repos/%s/%s/contents/README.md", owner, repo_name)
  return raw_url, api_url
end

return M
