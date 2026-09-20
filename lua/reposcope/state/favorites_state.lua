---@module 'reposcope.state.favorites_state'
---@brief Persists favorite repositories (metadata + README) across sessions.
---@description
--- A favorite is a lightweight snapshot of a `Repository` (owner, name,
--- description, html_url, default_branch, stargazers_count) plus, if already
--- cached, its README content: metadata and the matching README are persisted
--- together, so a favorite is self-contained and doesn't need a live re-fetch
--- to be useful later (e.g. as a start view).
---
--- Stored as a single JSON file under the plugin's cache directory, following
--- the same conventions as `state.session_state` (`safe_mkdir` before
--- writing, errors reported via `utils.debug.notify`). A corrupt file on
--- load is backed up before being replaced -- `io.open`/`file:write`'s
--- handle and write result are checked directly rather than trusting a
--- `pcall` around them, since neither reports failure through a Lua error
--- (same idiom as `cache.readme_cache`/`utils.metrics`/`state.query_stats`).
--- Loaded once and cached in memory; `toggle()` re-saves immediately, so a
--- crash never loses more than the single most recent change.

---@class FavoritesState : FavoritesStateModule
local M = {}

local get_favorites_path = require("reposcope.config").get_favorites_path
local notify = require("reposcope.utils.debug").notify
local readme_cache_get = require("reposcope.cache.readme_cache").get
local is_readable_file = require("lib.nvim.fs.is_readable_file")
local fs_read = require("lib.nvim.fs.read")
local fs_json = require("lib.nvim.fs.json")

---@type FavoriteRepo[]|nil
local _cache = nil

---Loads favorites from disk (cached after first call).
---
--- A decode failure on an existing file is not the same situation as no
--- file existing at all: `M.toggle()` always rewrites the WHOLE file via
--- `_save()`, so falling straight through to an empty list here means the
--- very next favorite toggled silently replaces a corrupt file with a
--- single-entry list -- every previously favorited repository gone with no
--- trace it ever existed. The original bytes are backed up once, so "the
--- file was briefly unreadable" never turns into "the favorites are gone".
---@return FavoriteRepo[]
function M.load()
  if _cache then return _cache end

  local path = get_favorites_path()
  if not is_readable_file(path) then
    _cache = {}
    return _cache
  end

  local decoded, err = fs_json.read(path)
  if not decoded or type(decoded) ~= "table" then
    local raw = fs_read(path)
    if raw and raw ~= "" then
      notify("[reposcope] Favorites file is corrupt or invalid JSON: " .. tostring(err), 4)
      local backup_path = path .. ".corrupt"
      -- Keep the earliest backup: a later restart that still finds the
      -- file corrupt must not clobber a first-corruption copy with a
      -- second, possibly different one (same idiom as
      -- readme_cache.lua/metrics.lua/query_stats.lua).
      if not is_readable_file(backup_path) then
        -- `io.open`/`file:write` report failure through a nil/false return,
        -- not a Lua error, so wrapping them in `pcall` alone never observes
        -- it (LLS-31) -- check the handle and the write result directly
        -- instead.
        local fh, open_err = io.open(backup_path, "wb")
        if not fh then
          notify("[reposcope] Failed to back up corrupt favorites file: " .. tostring(open_err), 4)
        else
          local ok_write, write_err = fh:write(raw)
          fh:close()
          if not ok_write then
            notify("[reposcope] Failed to back up corrupt favorites file: " .. tostring(write_err), 4)
          end
        end
      end
    end
    _cache = {}
    return _cache
  end

  _cache = decoded
  return _cache
end

---@private
---@internal
---Writes the current in-memory favorites list to disk.
---@return boolean success
local function _save()
  local path = get_favorites_path()
  local ok, err = fs_json.write(path, _cache or {})
  if not ok then
    notify("[reposcope] Failed to write favorites file: " .. tostring(err), 4)
    return false
  end

  return true
end

---Checks whether a repository is favorited.
---@param owner string
---@param name string
---@return boolean
function M.is_favorite(owner, name)
  local favs = M.load()
  for i = 1, #favs do
    if favs[i].owner == owner and favs[i].name == name then return true end
  end
  return false
end

---Toggles a repository's favorite status. Adding a favorite snapshots its
--- metadata and (if already cached) its README content; removing drops the
--- entry entirely.
---@param repo Repository
---@return boolean is_favorite_now
function M.toggle(repo)
  local favs = M.load()
  local owner = repo.owner and repo.owner.login
  local name = repo.name

  for i = 1, #favs do
    if favs[i].owner == owner and favs[i].name == name then
      table.remove(favs, i)
      _save()
      return false
    end
  end

  favs[#favs + 1] = {
    owner = owner,
    name = name,
    description = repo.description,
    html_url = repo.html_url,
    default_branch = repo.default_branch,
    stargazers_count = repo.stargazers_count,
    readme = readme_cache_get(owner, name),
  }
  _save()
  return true
end

---Returns a deep copy of the persisted favorites list.
---@return FavoriteRepo[]
function M.list() return vim.deepcopy(M.load()) end

---Removes all favorites.
---@return nil
function M.clear_all()
  _cache = {}
  _save()
end

return M
