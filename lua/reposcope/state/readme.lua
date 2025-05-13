---@class ReadmeCache
---@field cache_readme fun(repo_name: string, readme_text: string): nil Caches the README for a repository directly in RAM
---@field get_cached_readme fun(repo_name: string): string|nil Returns the cached README if available
local M = {}

local config = require("reposcope.config")
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
    notify("[reposcope] Repository not found: " .. repo_name, 4)
  end
end

---Returns the cached README if available
---@param repo_name string The name of the repository
function M.get_cached_readme(repo_name)
  local repo = repositories.get_repository(repo_name)
  return repo and repo.readme_cache or nil
end

--- Writes the README content to the file cache
---@param repo_name string The repository name
---@param readme_text string The README content
---@return boolean Success status
function M.fcache_readme(repo_name, readme_text)
  local repo = repositories.get_repository(repo_name)
  if not repo then
    notify("[reposcope] Repository not found: " .. repo_name, vim.log.levels.ERROR)
    return false
  end

  repo.readme_cache = readme_text

  local fcache_path = config.get_readme_fcache_dir()
  vim.fn.mkdir(fcache_path, "p")

  local readmefile = fcache_path .. "/" .. repo_name .. ".md"
  if vim.fn.filereadable(readmefile) == 1 then
    notify("[reposcope] README already cached: " .. readmefile, vim.log.levels.INFO)
  return false
  end

  local ok, err = pcall(function()
    local file = assert(io.open(readmefile, "w"))
    file:write(readme_text)
    file:close()
  end)

  if not ok then
    notify("[reposcope] Error writing README cache: " .. err, vim.log.levels.ERROR)
    return false
  end

  notify("[reposcope] README cached: " .. readmefile, vim.log.levels.INFO)
  return true
end

--- Reads the README content from the file cache
---@param repo_name string The repository name
---@return string|nil Cached README content or nil if not found
function M.get_fcached_readme(repo_name)
  local fcache_path = config.get_readme_fcache_dir()
  local readmefile = fcache_path .. "/" .. repo_name .. ".md"

  if vim.fn.filereadable(readmefile) == 0 then
    notify("[reposcope] README not cached: " .. readmefile, vim.log.levels.INFO)
    return nil
  end

  local ok, content = pcall(function()
    local file = assert(io.open(readmefile, "r"))
    local text = file:read("*a")
    file:close()
    return text
  end)

  if not ok then
    notify("[reposcope] Error reading README cache: " .. content, vim.log.levels.ERROR)
    return nil
  end

  notify("[reposcope] README loaded from cache: " .. readmefile, vim.log.levels.INFO)
  return content
end

return M
