---@class ReadmeManager
---@field fetch_readme_for_selected fun(): nil Initiates the README fetch for the currently selected repository
---@field get_readme_urls fun(owner: string, repo_name: string, branch: string): string, string Constructs the RAW and API URLs for the README
---@field try_fetch_readme fun(raw_url: string, api_url: string, repo_name: string): nil Attempts to fetch the README using the RAW URL, then the API as fallback
---@field fetch_readme_from_api fun(api_url: string, repo_name: string): nil Fetches the README using the GitHub API (fallback)
---@field private decode_base64 fun(encoded: string): string Decodes a Base64-encoded string (compatible with Lua)
local M = {}

local api = require("reposcope.network.api")
local metrics = require("reposcope.utils.metrics")
local readme_state = require("reposcope.state.readme")
local repositories = require("reposcope.state.repositories")
local preview = require("reposcope.ui.preview.inject")
local debug = require("reposcope.utils.debug")

local active_readme_requests = {}

--- Initiates the README fetch for the currently selected repository
function M.fetch_readme_for_selected()
  local repo = repositories.get_selected_repo()
  if not repo then
    debug.notify("[reposcope] No repository selected", 3)
    return
  end

  local owner = repo.owner and repo.owner.login
  local repo_name = repo.name
  local default_branch = repo.default_branch or "main"

  if not owner or not repo_name then
    debug.notify("[reposcope] Invalid repository URL", 4)
    return
  end

  -- Check if README is already being fetched
  if active_readme_requests[repo_name] then
    local is_cached, source = readme_state.has_cached_readme(repo_name)
    if is_cached then
      local uuid = metrics.generate_uuid()
      if metrics.record_metrics() then
        if source == "ram" then
          metrics.increase_cache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
        elseif source == "file" then
          metrics.increase_fcache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
        end
      end
      preview.show_readme(repo_name, source)
      return
    end
    return
  end

  active_readme_requests[repo_name] = true

  -- Check if README is cached (RAM or File)
  local is_cached, source = readme_state.has_cached_readme(repo_name)
  if is_cached then
    local uuid = metrics.generate_uuid()
    if metrics.record_metrics() then
      if source == "ram" then
        metrics.increase_cache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
      elseif source == "file" then
        metrics.increase_fcache_hit(uuid, repo_name, repo.html_url, "fetch_readme")
      end
    end
    preview.show_readme(repo_name, source)
    active_readme_requests[repo_name] = nil
    return
  end

  local raw_url, api_url = M.get_readme_urls(owner, repo_name, default_branch)
  M.try_fetch_readme(raw_url, api_url, repo_name)
end

--- Constructs the RAW and API URLs for the README
function M.get_readme_urls(owner, repo_name, branch)
  local raw_url = string.format("https://raw.githubusercontent.com/%s/%s/%s/README.md", owner, repo_name, branch)
  local api_url = string.format("https://api.github.com/repos/%s/%s/contents/README.md", owner, repo_name)
  return raw_url, api_url
end

--- Attempts to fetch the README using the RAW URL, then the API as fallback
function M.try_fetch_readme(raw_url, api_url, repo_name)
  local uuid = metrics.generate_uuid()
  local start_time = vim.loop.hrtime()
  local query = repo_name
  local source = "raw_readme"

  api.get(raw_url, function(response)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Calculate duration in milliseconds

    if response then
      if metrics.record_metrics() then
        metrics.increase_success(uuid, query, source, "fetch_readme", duration_ms, 200)
      end
      readme_state.cache_readme(repo_name, response)
      -- Write to file cache asynchronously (non-blocking)
      vim.schedule(function()
        readme_state.fcache_readme(repo_name, response)
        debug.notify("[reposcope] README cached to file: " .. repo_name, 1)
      end)
      preview.show_readme(repo_name)
      debug.notify("[reposcope] Successfully fetched README from RAW URL: " .. raw_url)
    else
      if metrics.record_metrics() then
        metrics.increase_failed(uuid, query, source, "fetch_readme", duration_ms, 404, "RAW URL failed")
      end
      debug.notify("[reposcope] Failed to fetch README from RAW URL. Trying API...", 2)
      M.fetch_readme_from_api(api_url, repo_name)
    end
  end, nil, nil, "fetch_readme")
end

--- Fetches the README using the GitHub API (fallback)
function M.fetch_readme_from_api(api_url, repo_name)
  local uuid = metrics.generate_uuid()
  local start_time = vim.loop.hrtime()
  local query = repo_name
  local source = "api_readme"

  api.get(api_url, function(response)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Calculate duration in milliseconds

    if response then
      local decoded = vim.json.decode(response)
      if decoded and decoded.content then
        local content = M.decode_base64(decoded.content)
        if metrics.record_metrics() then
          metrics.increase_success(uuid, query, source, "fetch_readme_api", duration_ms, 200)
        end
        readme_state.cache_readme(repo_name, content)
        -- Write to file cache asynchronously (non-blocking)
        vim.schedule(function()
          readme_state.fcache_readme(repo_name, response)
          debug.notify("[reposcope] README via API cached to file: " .. repo_name, 1)
        end)
        preview.show_readme(repo_name, "cache")
        debug.notify("[reposcope] Successfully fetched README via API: " .. api_url, 1) --REF: remove after debug
      else
        if metrics.record_metrics() then
          metrics.increase_failed(uuid, query, source, "fetch_readme_api", duration_ms, 500, "Invalid API response")
        end
        debug.notify("[reposcope] Invalid API response for README", 4)
      end
    else
      if metrics.record_metrics() then
        metrics.increase_failed(uuid, query, source, "fetch_readme_api", duration_ms, 404, "API URL failed")
      end
      debug.notify("[reposcope] Failed to fetch README via API", 4)
    end
  end, nil, nil, "fetch_readme")
end

--- Decodes a Base64-encoded string (compatible with Lua)
function M.decode_base64(encoded)
  local decoded = vim.fn.system("echo '" .. encoded .. "' | base64 --decode")
  return decoded
end

return M
