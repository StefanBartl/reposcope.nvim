---@module 'reposcope.cache.readme_cache'
---@brief Manages caching of README files (RAM and file-based)
---@description
--- This module handles in-memory and file-based caching for repository README content.
--- It supports checking for cache hits, writing to disk, and clearing entries or the entire cache.
--- Used internally to reduce redundant network requests and improve performance.
---
--- Freshness metadata (`has_fresh`/`set_updated_at`) is a lightweight sidecar
--- JSON file (`config.get_readme_meta_path()`), keyed the same way as the RAM
--- cache, mapping "owner/repo" to the repository's `updated_at` (or
--- provider-equivalent) value *at the time its README was cached*. The
--- actual `.md` files stay pure content — no wrapping metadata — so they
--- remain directly readable/editable, matching the existing UX.

---@class ReadmeCache : ReadmeCacheModule
local M = {}

-- Vim Utilities
local readdir = vim.fn.readdir
-- Config Module
local config = require("reposcope.config")
local get_readme_filecache_dir = config.get_readme_filecache_dir
local get_readme_meta_path = config.get_readme_meta_path
-- Utility Modules
local notify = require("reposcope.utils.debug").notify
-- lib.nvim
local is_readable_file = require("lib.nvim.fs.is_readable_file")
local fs_read = require("lib.nvim.fs.read")
local fs_write = require("lib.nvim.fs.write.to_file")
local fs_json = require("lib.nvim.fs.json")

M.readme_cache = {}

---@private
---@internal
---@param owner string
---@param repo_name string
---@return string
local function _get_key(owner, repo_name) return owner .. "/" .. repo_name end

---@private
---@internal
---@param owner string
---@param repo_name string
---@return string
local function _get_file_path(owner, repo_name)
  return get_readme_filecache_dir() .. "/" .. owner .. "__" .. repo_name .. ".md"
end

---@type table<string, string>|nil
local _meta = nil

---@private
---@internal
---Loads the freshness-metadata file from disk (cached after first call).
---@return table<string, string>
local function _load_meta()
  if _meta then return _meta end

  local path = get_readme_meta_path()
  if not is_readable_file(path) then
    _meta = {}
    return _meta
  end

  local decoded, err = fs_json.read(path)
  if not decoded or type(decoded) ~= "table" then
    notify("[reposcope] README freshness metadata is corrupt or invalid JSON: " .. tostring(err), 3)
    _meta = {}
    return _meta
  end

  _meta = decoded
  return _meta
end

---@private
---@internal
---Writes the current in-memory freshness metadata to disk.
---@return boolean success
local function _save_meta()
  local path = get_readme_meta_path()
  local ok, err = fs_json.write(path, _meta or {})
  if not ok then
    notify("[reposcope] Failed to write README freshness metadata: " .. tostring(err), 3)
    return false
  end

  return true
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
  if M.get_ram(owner, repo_name) then return true, "ram" end

  if is_readable_file(_get_file_path(owner, repo_name)) then return true, "file" end

  return false, nil
end

---Stores a README in RAM cache
---@param owner string
---@param repo_name string
---@return string|nil
function M.get_ram(owner, repo_name) return M.readme_cache[_get_key(owner, repo_name)] end

---Returns a README from RAM cache
---@param owner string
---@param repo_name string
---@param readme_text string
function M.set_ram(owner, repo_name, readme_text) M.readme_cache[_get_key(owner, repo_name)] = readme_text end

---Writes README content to the file cache
---@param owner string
---@param repo_name string
---@param readme_text string
---@return boolean
function M.set_file(owner, repo_name, readme_text)
  local path = _get_file_path(owner, repo_name)

  -- Always overwrites: every caller only reaches this after a real fetch
  -- succeeded, so an existing file here is a previous (possibly now stale,
  -- see has_fresh/set_updated_at) cache entry that must be replaced, not
  -- preserved.
  local ok, err = fs_write(path, readme_text)

  if not ok then
    notify("[reposcope] Error writing README cache: " .. tostring(err), vim.log.levels.ERROR)
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
  if not is_readable_file(path) then return nil end

  local content, err = fs_read(path)

  if not content then
    notify("[reposcope] Error reading README cache: " .. tostring(err), vim.log.levels.ERROR)
    return nil
  end

  M.readme_cache[_get_key(owner, repo_name)] = content

  return content
end

---Returns the repository `updated_at` value recorded when its README was
--- last cached, or `nil` if never recorded (e.g. cached before this feature,
--- or the provider doesn't supply the field).
---@param owner string
---@param repo_name string
---@return string|nil
function M.get_cached_updated_at(owner, repo_name) return _load_meta()[_get_key(owner, repo_name)] end

---Records the repository `updated_at` value a README was cached under.
--- No-op for a nil/empty `updated_at` (nothing to compare against later).
---@param owner string
---@param repo_name string
---@param updated_at string|nil
---@return nil
function M.set_updated_at(owner, repo_name, updated_at)
  if type(updated_at) ~= "string" or updated_at == "" then return end
  local meta = _load_meta()
  meta[_get_key(owner, repo_name)] = updated_at
  _save_meta()
end

---Like `M.has`, but additionally treats the cache as a miss when `updated_at`
--- is given and differs from the value recorded at cache time — i.e. the
--- repository changed since its README was cached, so the cached content may
--- be stale. When `updated_at` is nil/empty (provider doesn't supply it),
--- this degrades to plain `M.has` — no information to compare, so the
--- existing cache is trusted.
---@param owner string
---@param repo_name string
---@param updated_at string|nil
---@return boolean, "ram"|"file"|nil
function M.has_fresh(owner, repo_name, updated_at)
  local ok, source = M.has(owner, repo_name)
  if not ok then return false, nil end

  if type(updated_at) ~= "string" or updated_at == "" then return true, source end

  local cached_updated_at = M.get_cached_updated_at(owner, repo_name)
  if cached_updated_at ~= nil and cached_updated_at ~= updated_at then return false, nil end

  return true, source
end

---Preloads every file-cached README into the RAM cache. Intended to run once
--- during `setup()`: the file cache survives restarts, but a fresh Neovim
--- session otherwise still pays a disk read on the first navigation to each
--- repository even though the content was already on disk.
---@return integer warmed Number of entries loaded into RAM
function M.warm_ram_from_file_cache()
  local dir = get_readme_filecache_dir()
  local warmed = 0

  -- The cache directory is created lazily, by the first `set_file` write
  -- (fs.write.to_file does the mkdir -p). Until someone has actually cached a
  -- README, it does not exist -- and this runs on every setup().
  --
  -- The `pcall` below does NOT cover that: `vim.fn.readdir` on a missing
  -- directory raises no Lua error, it *echoes* "E484: Can't open file <dir>"
  -- and returns an empty list. pcall reports ok=true, so the message reached
  -- the user on every single startup. Check for the directory instead.
  local stat = (vim.uv or vim.loop).fs_stat(dir)
  if not stat or stat.type ~= "directory" then return 0 end

  local ok, files = pcall(readdir, dir)
  if not ok or type(files) ~= "table" then return 0 end

  for _, file in ipairs(files) do
    local owner, repo_name = file:match("^(.+)__(.+)%.md$")
    if owner and repo_name and not M.get_ram(owner, repo_name) then
      local content = M.get_file(owner, repo_name) -- also populates RAM as a side effect
      if content then warmed = warmed + 1 end
    end
  end

  return warmed
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
    if is_readable_file(path) then
      os.remove(path)
      cleared = true
    end
  end

  if cleared then
    local meta = _load_meta()
    if meta[key] then
      meta[key] = nil
      _save_meta()
    end
  end

  return cleared
end

---Clears all README caches (RAM, file, and freshness metadata)
---@return boolean
function M.clear_all()
  M.readme_cache = {}
  _meta = {}
  _save_meta()

  local dir = get_readme_filecache_dir()
  local stat = (vim.uv or vim.loop).fs_stat(dir)

  -- Nothing on disk to clear, and readdir would echo E484 (see
  -- warm_ram_from_file_cache for why pcall does not suppress that).
  local ok, err = true, nil
  if stat and stat.type == "directory" then
    ok, err = pcall(function()
      for _, file in ipairs(readdir(dir)) do
        os.remove(dir .. "/" .. file)
      end
    end)
  end

  if not ok then notify("[reposcope] " .. err, 3) end

  collectgarbage("collect")
  return ok or false
end

return M
