---@class ReadmeManager
---@field fetch_readme_for_selected fun(): nil Initiates the README fetch for the currently selected repository
---@field get_readme_urls fun(owner: string, repo_name: string, branch: string): string, string Constructs the RAW and API URLs for the README
---@field try_fetch_readme fun(raw_url: string, api_url: string, repo_name: string): nil Attempts to fetch the README using the RAW URL, then the API as fallback
---@field fetch_readme_from_api fun(api_url: string, repo_name: string): nil Fetches the README using the GitHub API (fallback)
---@field private decode_base64 fun(encoded: string): string Decodes a Base64-encoded string (compatible with Lua)
local M = {}

local api = require("reposcope.utils.api")
local readme = require("reposcope.state.readme")
local repositories = require("reposcope.state.repositories")
local preview = require("reposcope.ui.preview.inject")
local notify = require("reposcope.utils.debug").notify

--- Initiates the README fetch for the currently selected repository
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

--- Constructs the RAW and API URLs for the README
function M.get_readme_urls(owner, repo_name, branch)
  local raw_url = string.format("https://raw.githubusercontent.com/%s/%s/%s/README.md", owner, repo_name, branch)
  local api_url = string.format("https://api.github.com/repos/%s/%s/contents/README.md", owner, repo_name)
  return raw_url, api_url
end

--- Attempts to fetch the README using the RAW URL, then the API as fallback
function M.try_fetch_readme(raw_url, api_url, repo_name)
  api.get(raw_url, function(response)
    if response then
      readme.cache_readme(repo_name, response)
      preview.show_readme(repo_name)
      notify("[reposcope] Successfully fetched README from RAW URL.")
    else
      notify("[reposcope] Failed to fetch README from RAW URL. Trying API...", vim.log.levels.WARN)
      M.fetch_readme_from_api(api_url, repo_name)
    end
  end, nil, nil, "fetch_readme")
end

--- Fetches the README using the GitHub API (fallback)
function M.fetch_readme_from_api(api_url, repo_name)
  api.get(api_url, function(response)
    if response then
      local decoded = vim.json.decode(response)
      if decoded and decoded.content then
        local content = M.decode_base64(decoded.content)
        readme.cache_readme(repo_name, content)
        preview.show_readme(repo_name)
        notify("[reposcope] Successfully fetched README via API.")
      else
        notify("[reposcope] Invalid API response for README", vim.log.levels.ERROR)
      end
    else
      notify("[reposcope] Failed to fetch README via API", vim.log.levels.ERROR)
    end
  end, nil, nil, "fetch_readme")
end

--- Decodes a Base64-encoded string (compatible with Lua)
function M.decode_base64(encoded)
  local decoded = vim.fn.system("echo '" .. encoded .. "' | base64 --decode")
  return decoded
end

return M
