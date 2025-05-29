---@module 'reposcope.cache.readme_cache'
---@class ReadmeCache
---@brief Caches README content for repositories in RAM and file.
---@description
--- Handles all cache operations for repository READMEs.
--- Includes RAM- and file-based caching as well as inspection and clearing.
---@alias Readme table<string, string>
---@field active_requests table<string, boolean> Tracks active readme requests
---@field readme_cache Readme RAM cache for fetched README contents
---@field get fun(repo_name: string): string|nil Returns README content from cache
---@field has fun(repo_name: string): boolean, "ram"|"file"|nil Checks if README exists in cache
---@field set_ram fun(repo_name: string, text: string): nil Stores README in RAM cache
---@field get_ram fun(repo_name: string): string|nil Retrieves README from RAM cache
---@field set_file fun(repo_name: string, text: string): boolean Saves README to file cache
---@field get_file fun(repo_name: string): string|nil Loads README from file cache
---@field clear fun(repo_name: string, target?: "ram"|"file"|"both"): boolean Clears README cache (RAM/file)
---@field clear_all fun(): boolean Clears all README cache entries (RAM/file)
local M = {}

-- Config Module
local config = require("reposcope.config")
-- Utility Modules
local notify = require("reposcope.utils.debug").notify
local safe_mkdir = require("reposcope.utils.protection").safe_mkdir

M.active_requests = {}
M.readme_cache = {}

---Returns the README content for a given repository from cache (RAM or file)
---@param repo_name string
---@return string|nil
function M.get(repo_name)
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.get: invalid repo_name")
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
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.has: invalid repo_name")

  if M.get_ram(repo_name) then
    return true, "ram"
  end

  local path = config.get_readme_fcache_dir() .. "/" .. repo_name .. ".md"
  if vim.fn.filereadable(path) == 1 then
    return true, "file"
  end

  return false, nil
end

---Stores a README in RAM cache
---@param repo_name string
---@param readme_text string
---@return nil
function M.set_ram(repo_name, readme_text)
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.set_ram: invalid repo_name")
  assert(type(readme_text) == "string", "readme_cache.set_ram: readme_text must be string")

  M.readme_cache[repo_name] = readme_text
end

---Returns a README from RAM cache
---@param repo_name string
---@return string|nil
function M.get_ram(repo_name)
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.get_ram: invalid repo_name")
  return M.readme_cache[repo_name]
end

---Writes README content to the file cache
---@param repo_name string
---@param readme_text string
---@return boolean
function M.set_file(repo_name, readme_text)
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.set_file: invalid repo_name")
  assert(type(readme_text) == "string", "readme_cache.set_file: readme_text must be string")

  local dir = config.get_readme_fcache_dir()
  safe_mkdir(dir)

  local path = dir .. "/" .. repo_name .. ".md"
  if vim.fn.filereadable(path) == 1 then
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
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.get_file: invalid repo_name")

  local path = config.get_readme_fcache_dir() .. "/" .. repo_name .. ".md"
  if vim.fn.filereadable(path) == 0 then return nil end

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
  assert(type(repo_name) == "string" and repo_name ~= "", "readme_cache.clear: invalid repo_name")

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
    local path = config.get_readme_fcache_dir() .. "/" .. repo_name .. ".md"
    if vim.fn.filereadable(path) == 1 then
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

  local dir = config.get_readme_fcache_dir()
  local ok, err = pcall(function()
    for file in vim.fn.readdir(dir) do
      os.remove(dir .. "/" .. file)
    end
  end)

  if not ok then
    notify("[reposcope] " .. err, 3)
  end

  return ok or false
end

return M
