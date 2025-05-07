---@class ReadmeCache
---@field cache_readme fun(repo_name: string, readme_text: string): nil Caches the README for a repository directly in RAM
---@field get_readme fun(repo_name: string): string|nil Returns the cached README if available
local M = {}

local repositories = require("reposcope.state.repositories")
local notify = require("reposcope.utils.debug").notify

---Caches the README for a repository directly in RAM
---@param repo_name string The name of the repository
---@param readme_text string The content of the README file
function M.cache_readme(repo_name, readme_text)
  local repo = repositories.get_repository(repo_name)
  if repo then
    repo.readme_cache = readme_text
  else
    notify("[reposcope] Repository not found: " .. repo_name, vim.log.levels.ERROR)
  end
end

---Returns the cached README if available
---@param repo_name string The name of the repository
function M.get_readme(repo_name)
  local repo = repositories.get_repository(repo_name)
  return repo and repo.readme_cache or nil
end

return M
