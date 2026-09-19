---@module 'reposcope.state.query_stats'
---@brief Tracks how often each search query has been run, persisted across sessions.
---@description
--- Every real search (`prompt_input.on_enter`) increments a persisted counter
--- keyed by the exact built query string via `M.record`. Backs
--- `:Reposcope queries` (top-N by frequency), the query-history companion to
--- repository favorites (`state.favorites_state`).
---
--- Same persistence conventions as `state.session_state`/`state.favorites_state`:
--- a single JSON file under the plugin's cache directory, `safe_mkdir` before
--- writing, `pcall`-wrapped `io.open`/read/write/close, errors reported via
--- `utils.debug.notify`.

---@class QueryStats : QueryStatsModule
local M = {}

local get_query_stats_path = require("reposcope.config").get_query_stats_path
local notify = require("reposcope.utils.debug").notify
local is_readable_file = require("lib.nvim.fs.is_readable_file")
local fs_read = require("lib.nvim.fs.read")
local fs_json = require("lib.nvim.fs.json")

---@type table<string, integer>|nil
local _cache = nil

---Loads query run-counts from disk (cached after first call).
---
--- A decode failure on an existing file is not the same situation as no
--- file existing at all: `M.record()` always rewrites the WHOLE file via
--- `_save()`, so falling straight through to an empty table here means the
--- very next recorded query silently replaces a corrupt file with a
--- single-entry table -- the whole query-frequency history gone with no
--- trace it ever existed. The original bytes are backed up once, so "the
--- file was briefly unreadable" never turns into "the history is gone".
---@return table<string, integer>
function M.load()
  if _cache then return _cache end

  local path = get_query_stats_path()
  if not is_readable_file(path) then
    _cache = {}
    return _cache
  end

  local decoded, err = fs_json.read(path)
  if not decoded or type(decoded) ~= "table" then
    local raw = fs_read(path)
    if raw and raw ~= "" then
      notify("[reposcope] Query stats file is corrupt or invalid JSON: " .. tostring(err), 4)
      local backup_path = path .. ".corrupt"
      -- Keep the earliest backup: a later restart that still finds the
      -- file corrupt must not clobber a first-corruption copy with a
      -- second, possibly different one (mirrors readme_cache.lua/metrics.lua).
      if not is_readable_file(backup_path) then
        -- `io.open`/`file:write` report failure through a nil/false return,
        -- not a Lua error, so wrapping them in `pcall` alone never observes
        -- it -- check the handle and the write result directly instead.
        local fh, open_err = io.open(backup_path, "wb")
        if not fh then
          notify("[reposcope] Failed to back up corrupt query stats file: " .. tostring(open_err), 4)
        else
          local ok_write, write_err = fh:write(raw)
          fh:close()
          if not ok_write then
            notify("[reposcope] Failed to back up corrupt query stats file: " .. tostring(write_err), 4)
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
---Writes the current in-memory query stats to disk.
---@return boolean success
local function _save()
  local path = get_query_stats_path()
  local ok, err = fs_json.write(path, _cache or {})
  if not ok then
    notify("[reposcope] Failed to write query stats file: " .. tostring(err), 4)
    return false
  end

  return true
end

---Increments the persisted run-count for `query`. No-op for an empty/invalid query.
---@param query string
---@return nil
function M.record(query)
  if type(query) ~= "string" or query == "" then return end

  local stats = M.load()
  stats[query] = (stats[query] or 0) + 1
  _save()
end

---Returns the top `n` queries by run count, most-frequent first (ties broken
--- alphabetically for a stable order).
---@param n integer
---@return { query: string, count: integer }[]
function M.top(n)
  local stats = M.load()

  local list = {}
  for query, count in pairs(stats) do
    list[#list + 1] = { query = query, count = count }
  end

  table.sort(list, function(a, b)
    if a.count ~= b.count then return a.count > b.count end
    return a.query < b.query
  end)

  local top = {}
  for i = 1, math.min(n, #list) do
    top[i] = list[i]
  end
  return top
end

---Removes all recorded query stats.
---@return nil
function M.clear_all()
  _cache = {}
  _save()
end

return M
