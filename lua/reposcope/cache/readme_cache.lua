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

---Returns the README content for a given repository from cache (RAM or file)
---@param repo_name string
---@return string|nil
function M.get(repo_name)
  local ok, source = M.has(repo_name)
  if not ok then return nil end

  if source == "ram" then
    return M.get_ram(repo_name)
  elseif source == "file" then
    return M.get_file(repo_name)
  end

  return nil
end

---Checks if a README is cached (RAM or File)
---@param repo_name string
---@return boolean, "ram"|"file"|nil
function M.has(repo_name)
  if M.get_ram(repo_name) then
    return true, "ram"
  end

  local path = get_readme_filecache_dir() .. "/" .. repo_name .. ".md"
  if filereadable(path) == 1 then
    return true, "file"
  end

  return false, nil
end

---Stores a README in RAM cache
---@param repo_name string
---@param readme_text string
---@return nil
function M.set_ram(repo_name, readme_text)
  M.readme_cache[repo_name] = readme_text
end

---Returns a README from RAM cache
---@param repo_name string
---@return string|nil
function M.get_ram(repo_name)
  return M.readme_cache[repo_name]
end

---Writes README content to the file cache
---@param repo_name string
---@param readme_text string
---@return boolean
function M.set_file(repo_name, readme_text)
  local dir = get_readme_filecache_dir()
  safe_mkdir(dir)

  local path = dir .. "/" .. repo_name .. ".md"
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
---@param repo_name string
---@return string|nil
function M.get_file(repo_name)
  local path = get_readme_filecache_dir() .. "/" .. repo_name .. ".md"
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

  -- Optionale RAM-Aktualisierung
  if content then M.readme_cache[repo_name] = content end
  return content
end

---Clears README cache for a repository (RAM, file or both)
---@param repo_name string
---@param target? "ram"|"file"|"both"
---@return boolean
function M.clear(repo_name, target)
  target = target or "both"

  if target ~= "ram" and target ~= "file" and target ~= "both" then
    notify("[reposcope] Invalid target for clear: " .. tostring(target), vim.log.levels.ERROR)
    return false
  end

  local cleared = false

  if target == "ram" or target == "both" then
    if M.readme_cache[repo_name] then
      M.readme_cache[repo_name] = nil
      cleared = true
    end
  end

  if target == "file" or target == "both" then
    local path = get_readme_filecache_dir() .. "/" .. repo_name .. ".md"
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
