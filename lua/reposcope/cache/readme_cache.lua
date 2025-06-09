---@module 'reposcope.cache.readme_cache'
---@brief Manages caching of README files (RAM and file-based)
---@description
--- This module handles in-memory and file-based caching for repository README content.
--- It supports checking for cache hits, writing to disk, and clearing entries or the entire cache.
--- Used internally to reduce redundant network requests and improve performance.

---@class ReadmeCache : ReadmeCacheModule
local M = {}

-- Vim Utilities
local filereadable = vim.fn.filereadable
local readdir = vim.fn.readdir
-- Config Module
local get_readme_filecache_dir = require("reposcope.config").get_readme_filecache_dir
-- Utility Modules
local notify = require("reposcope.utils.debug").notify
local safe_mkdir = require("reposcope.utils.protection").safe_mkdir


M.readme_cache = {}

---@private
---@param owner string
---@param repo_name string
---@return string
local function _get_key(owner, repo_name)
  return owner .. "/" .. repo_name
end


---@private
---@param owner string
---@param repo_name string
---@return string
local function _get_file_path(owner, repo_name)
  return get_readme_filecache_dir() .. "/" .. owner .. "__" .. repo_name .. ".md"
end


---Returns the README content for a given repository from cache (RAM or file)
---@param owner string
---@param repo_name string
---@return string|nil
function M.get(owner, repo_name)
  local ok, source = M.has(owner, repo_name)
  if not ok then return nil end

  if source == "ram" then
    return M.get_ram(owner, repo_name)
  elseif source == "file" then
    return M.get_file(owner, repo_name)
  end
end

---Checks if a README is cached (RAM or File)
---@param owner string
---@param repo_name string
---@return boolean, "ram"|"file"|nil
function M.has(owner, repo_name)
  if M.get_ram(owner, repo_name) then
    return true, "ram"
  end

  if filereadable(_get_file_path(owner, repo_name)) == 1 then
    return true, "file"
  end

  return false, nil
end

---Stores a README in RAM cache
---@param owner string
---@param repo_name string
---@return string|nil
function M.get_ram(owner, repo_name)
  return M.readme_cache[_get_key(owner, repo_name)]
end


---Returns a README from RAM cache
---@param owner string
---@param repo_name string
---@param readme_text string
function M.set_ram(owner, repo_name, readme_text)
  M.readme_cache[_get_key(owner, repo_name)] = readme_text
end

---Writes README content to the file cache
---@param owner string
---@param repo_name string
---@param readme_text string
---@return boolean
function M.set_file(owner, repo_name, readme_text)
  local path = _get_file_path(owner, repo_name)
  safe_mkdir(get_readme_filecache_dir())

  if filereadable(path) == 1 then
    return false
  end

  local ok, err = pcall(function()
    local f = assert(io.open(path, "w"))
    f:write(readme_text)
    f:close()
  end)

  if not ok then
    notify("[reposcope] Error writing README cache: " .. err, vim.log.levels.ERROR)
    return false
  end

  return true
end

---Loads README content from the file cache
---@param owner string
---@param repo_name string
---@return string|nil
function M.get_file(owner, repo_name)
  local path = _get_file_path(owner, repo_name)
  if filereadable(path) == 0 then return nil end

  local ok, content = pcall(function()
    local f = assert(io.open(path, "r"))
    local t = f:read("*a")
    f:close()
    return t
  end)

  if not ok then
    notify("[reposcope] Error reading README cache: " .. content, vim.log.levels.ERROR)
    return nil
  end

  if content then
    M.readme_cache[_get_key(owner, repo_name)] = content
  end

  return content
end

---Clears README cache for a repository (RAM, file or both)
---@param owner string
---@param repo_name string
---@param target? "ram"|"file"|"both"
---@return boolean
function M.clear(owner, repo_name, target)
  target = target or "both"
  local key = _get_key(owner, repo_name)
  local path = _get_file_path(owner, repo_name)
  local cleared = false

  if target == "ram" or target == "both" then
    if M.readme_cache[key] then
      M.readme_cache[key] = nil
      cleared = true
    end
  end

  if target == "file" or target == "both" then
    if filereadable(path) == 1 then
      os.remove(path)
      cleared = true
    end
  end

  return cleared
end

---Clears all README caches (RAM and file)
---@return boolean
function M.clear_all()
  M.readme_cache = {}

  local dir = get_readme_filecache_dir()
  local ok, err = pcall(function()
    for file in readdir(dir) do
      os.remove(dir .. "/" .. file)
    end
  end)

  if not ok then
    notify("[reposcope] " .. err, 3)
  end

  collectgarbage("collect")
  return ok or false
end

return M
