---@module 'reposcope.state.favorites_state'
---@brief Persists favorite repositories (metadata + README) across sessions.
---@description
--- A favorite is a lightweight snapshot of a `Repository` (owner, name,
--- description, html_url, default_branch, stargazers_count) plus, if already
--- cached, its README content — the roadmap explicitly wants "Repo-Metadaten
--- + zugehörige README" persisted together, so a favorite is self-contained
--- and doesn't need a live re-fetch to be useful later (e.g. as a start view).
---
--- Stored as a single JSON file under the plugin's cache directory, following
--- the same conventions as `state.session_state` (`safe_mkdir` before
--- writing, `pcall`-wrapped `io.open`/read/write/close, errors reported via
--- `utils.debug.notify`). Loaded once and cached in memory; `toggle()`
--- re-saves immediately, so a crash never loses more than the single most
--- recent change.

---@class FavoritesState : FavoritesStateModule
local M = {}

local get_favorites_path = require("reposcope.config").get_favorites_path
local notify = require("reposcope.utils.debug").notify
local readme_cache_get = require("reposcope.cache.readme_cache").get
local is_readable_file = require("lib.nvim.fs.is_readable_file")
local fs_json = require("lib.nvim.fs.json")

---@type FavoriteRepo[]|nil
local _cache = nil

---Loads favorites from disk (cached after first call).
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
    notify("[reposcope] Favorites file is corrupt or invalid JSON: " .. tostring(err), 4)
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
