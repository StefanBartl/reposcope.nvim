---@class ReadmeManager
---@field fetch_readme_for_selected fun(): nil Initiates the README fetch for the currently selected repository
---@field get_readme_urls fun(owner: string, repo_name: string, branch: string): string, string Constructs the RAW and API URLs for the README
---@field try_fetch_readme fun(raw_url: string, api_url: string, repo_name: string): nil Attempts to fetch the README using the RAW URL, then the API as fallback
---@field fetch_readme_from_api fun(api_url: string, repo_name: string): nil Fetches the README using the GitHub API (fallback)
---@field private decode_base64 fun(encoded: string): string Decodes a Base64-encoded string (compatible with Lua)
local M = {}
local http = require("reposcope.utils.http")
local readme = require("reposcope.state.readme")
local repositories = require("reposcope.state.repositories")
local preview = require("reposcope.ui.preview.inject")
local config = require("reposcope.config")
local notify = require("reposcope.utils.debug").notify
local profiler = require("reposcope.utils.debug")

---Initiates the README fetch for the currently selected repository
function M.fetch_readme_for_selected()
  local repo = repositories.get_selected_repo()
  if not repo then
    notify("[reposcope] No repository selected", vim.log.levels.WARN)
    return
  end

  local owner = repo.owner and repo.owner.login
  local repo_name = repo.name
  local default_branch = repo.default_branch or "main"

  if not owner or not repo_name then
    notify("[reposcope] Invalid repository URL", vim.log.levels.ERROR)
    return
  end

  local raw_url, api_url = M.get_readme_urls(owner, repo_name, default_branch)
  M.try_fetch_readme(raw_url, api_url, repo_name)
end

---Constructs the RAW and API URLs for the README
---@param owner string The owner of the repository
---@param repo_name string The name of the repository
---@param branch string The branch name (usually "main" or "master")
---@return string, string The RAW URL and the API URL
function M.get_readme_urls(owner, repo_name, branch)
  local raw_url = string.format("https://raw.githubusercontent.com/%s/%s/%s/README.md", owner, repo_name, branch)
  local api_url = string.format("https://api.github.com/repos/%s/%s/contents/README.md", owner, repo_name)
  return raw_url, api_url
end

---Attempts to fetch the README using the RAW URL, then the API as fallback
---@param raw_url string RAW URL
---@param api_url string API URL
---@param repo_name string Repository name
function M.try_fetch_readme(raw_url, api_url, repo_name)
  -- Check if README is already cached
  local cached_content = readme.get_readme(repo_name)
  if cached_content then
    notify("[reposcope] README already cached, using cache.", vim.log.levels.INFO)
    preview.show_readme(repo_name)
    return
  end

  notify("[reposcope] Fetching README: " .. raw_url)
  profiler.increase_req()

  http.get(raw_url, function(response)
    if response then
      notify("[reposcope] Successfully fetched README from RAW URL.")
      readme.cache_readme(repo_name, response)
      preview.show_readme(repo_name)
      profiler.increase_success()
    else
      notify("[reposcope] Failed to fetch README from RAW URL. Trying API...", vim.log.levels.WARN)
      profiler.increase_failed()
      M.fetch_readme_from_api(api_url, repo_name)
    end
  end, config.is_debug_mode())
end

---Fetches the README using the GitHub API (fallback)
---@param api_url string The API URL for the README
---@param repo_name string The name of the repository
function M.fetch_readme_from_api(api_url, repo_name)
  notify("[reposcope] Fetching README via API: " .. api_url)
  profiler.increase_req()

  http.get(api_url, function(response)
    if not response then
      notify("[reposcope] Failed to fetch README via API", vim.log.levels.ERROR)
      profiler.increase_failed()
      return
    end

    local decoded = vim.json.decode(response)
    if decoded and decoded.content then
      local content = M.decode_base64(decoded.content)
      readme.cache_readme(repo_name, content)
      preview.show_readme(repo_name)
      notify("[reposcope] Successfully fetched README via API.")
      profiler.increase_success()
    else
      notify("[reposcope] Invalid API response for README", vim.log.levels.ERROR)
      profiler.increase_failed()
    end
  end, config.is_debug_mode())
end

--- Decodes a Base64-encoded string (compatible with Lua)
---@param encoded string Base64 encoded content
---@return string Decoded content
function M.decode_base64(encoded)
  local decoded = vim.fn.system("echo '" .. encoded .. "' | base64 --decode")
  return decoded
end

return M
