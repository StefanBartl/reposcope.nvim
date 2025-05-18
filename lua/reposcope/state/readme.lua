---@class ReadmeCache
---@field active_readme_requests table Holds state for active requests to README files in repositories
---@field has_cached_readme fun(repo_name: string): boolean, string|nil Checks if a README is cached (RAM or File)
---@field cache_readme fun(repo_name: string, readme_text: string): nil Caches the README for a repository directly in RAM
---@field get_cached_readme fun(repo_name: string): string|nil Returns the cached README if available
---@field fcache_readme fun(repo_name: string, readme_text: string): boolean Writes the README content to the file cache
---@field get_fcached_readme fun(repo_name: string): string|nil Reads the README content from the file cache
---@field clear_cache fun(repo_name: string): boolean Clears the README cache (RAM and File) for a specific repository
---@field clear_all_caches fun(): boolean Clears all README caches (RAM and File) for all repositories
local M = {}

local config = require("reposcope.config")
local repo_state = require("reposcope.state.repositories")
local notify = require("reposcope.utils.debug").notify

M.active_readme_requests = {}

--- Checks if a README is cached (RAM or File)
---@param repo_name string The repository name
---@return boolean, string|nil Cached status (true/false) and source ("ram", "file" or nil)
function M.has_cached_readme(repo_name)
  -- Check RAM
  if M.get_cached_readme(repo_name) then
    return true, "ram"
  end

  -- Check File cache
  local fcache_path = config.get_readme_fcache_dir()
  local readmefile = fcache_path .. "/" .. repo_name .. ".md"
  if vim.fn.filereadable(readmefile) == 1 then
    return true, "file"
  end

  return false, nil
end

--- Caches the README for a repository directly in RAM
---@param repo_name string The name of the repository
---@param readme_text string The content of the README file
---@return nil
function M.cache_readme(repo_name, readme_text)
  local repo = repo_state.get_repository(repo_name)
  if repo then
    repo.readme_cache = readme_text
  else
    notify("[reposcope] Repository not found: " .. repo_name, 4)
  end
end

--- Returns the cached README if available in RAM
---@param repo_name string The name of the repository
---@return string|nil Cached README content or nil if not found
function M.get_cached_readme(repo_name)
  local repo = repo_state.get_repository(repo_name)
  return repo and repo.readme_cache or nil
end

--- Writes the README content to the file cache
---@param repo_name string The repository name
---@param readme_text string The README content
---@return boolean Success status (true if written, false on error)
function M.fcache_readme(repo_name, readme_text)
  local repo = repo_state.get_repository(repo_name)
  if not repo then
    notify("[reposcope] Repository not found: " .. repo_name, 4)
    return false
  end

  repo.readme_cache = readme_text

  local fcache_path = config.get_readme_fcache_dir()
  require("reposcope.utils.protection").safe_mkdir(fcache_path)

  local readmefile = fcache_path .. "/" .. repo_name .. ".md"

  if vim.fn.filereadable(readmefile) == 1 then
    notify("[reposcope] README already cached: " .. readmefile, 2)
    return false
  end

  local ok, err = pcall(function()
    local file = assert(io.open(readmefile, "w"))
    file:write(readme_text)
    file:close()
  end)

  if not ok then
    notify("[reposcope] Error writing README cache: " .. err, 4)
    return false
  end

  notify("[reposcope] README cached: " .. readmefile, 2)
  return true
end

--- Reads the README content from the file cache
---@param repo_name string The repository name
---@return string|nil Cached README content or nil if not found
function M.get_fcached_readme(repo_name)
  local fcache_path = config.get_readme_fcache_dir()
  local readmefile = fcache_path .. "/" .. repo_name .. ".md"

  if vim.fn.filereadable(readmefile) == 0 then
    notify("[reposcope] README not cached: " .. readmefile, 2)
    return nil
  end

  local ok, content = pcall(function()
    local file = assert(io.open(readmefile, "r"))
    local text = file:read("*a")
    file:close()
    return text
  end)

  if not ok then
    notify("[reposcope] Error reading README cache: " .. content, 4)
    return nil
  end

  if content then
    M.cache_readme(repo_name, content) -- save in RAM-Cache
  end

  notify("[reposcope] README loaded from file cache: " .. readmefile, 2)
  return content
end

--- Clears the README cache (RAM and File) for a specific repository
---@param repo_name string The repository name
---@return boolean Success status (true if cleared, false on error)
function M.clear_cache(repo_name)
  local repo = repo_state.get_repository(repo_name)
  if not repo then
    notify("[reposcope] Repository not found: " .. repo_name, 4)
    return false
  end

  -- RAM-Cache löschen
  if repo.readme_cache then
    repo.readme_cache = nil
    notify("[reposcope] README removed from RAM cache: " .. repo_name, 2)
  end

  -- Dateicache löschen
  local fcache_path = config.get_readme_fcache_dir()
  local readmefile = fcache_path .. "/" .. repo_name .. ".md"
  if vim.fn.filereadable(readmefile) == 1 then
    os.remove(readmefile)
    notify("[reposcope] README removed from file cache: " .. readmefile, 2)
  end

  return true
end

--- Clears all README caches (RAM and File) for all repositories
---@return boolean Success status (true if all cleared, false on error)
function M.clear_all_caches()
  -- RAM-Cache für alle Repositories leeren
  local repositories = repo_state.get_repositories().items

  for _, repo in ipairs(repositories) do
    if repo.readme_cache then
      repo.readme_cache = nil
    end
  end
  notify("[reposcope] All READMEs removed from RAM cache.", 2)

  -- Alle Dateien im Dateicache löschen
  local fcache_path = config.get_readme_fcache_dir()
  local success, err = pcall(function()
    for file in vim.fn.readdir(fcache_path) do
      os.remove(fcache_path .. "/" .. file)
    end
  end)

  if success then
    notify("[reposcope] All README files removed from file cache.", 2)
    return true
  else
    notify("[reposcope] Error clearing all file caches: " .. err, 4)
    return false
  end
end

return M
