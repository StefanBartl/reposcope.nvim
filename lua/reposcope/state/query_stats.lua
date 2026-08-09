---@module 'reposcope.state.query_stats'
---@brief Tracks how often each search query has been run, persisted across sessions.
---@description
--- Every real search (`prompt_input.on_enter`) increments a persisted counter
--- keyed by the exact built query string via `M.record`. Backs
--- `:Reposcope queries` (top-N by frequency) — the roadmap's "Häufigste
--- Queries mitschreiben und ebenfalls anbieten" companion to repository
--- favorites (`state.favorites_state`).
---
--- Same persistence conventions as `state.session_state`/`state.favorites_state`:
--- a single JSON file under the plugin's cache directory, `safe_mkdir` before
--- writing, `pcall`-wrapped `io.open`/read/write/close, errors reported via
--- `utils.debug.notify`.

---@class QueryStats : QueryStatsModule
local M = {}

local get_query_stats_path = require("reposcope.config").get_query_stats_path
local safe_mkdir = require("reposcope.utils.protection").safe_mkdir
local notify = require("reposcope.utils.debug").notify
local filereadable = vim.fn.filereadable
local fnamemodify = vim.fn.fnamemodify

---@type table<string, integer>|nil
local _cache = nil

---Loads query run-counts from disk (cached after first call).
---@return table<string, integer>
function M.load()
  if _cache then return _cache end

  local path = get_query_stats_path()
  if filereadable(path) == 0 then
    _cache = {}
    return _cache
  end

  local read_ok, content = pcall(function()
    local f = assert(io.open(path, "r"))
    local text = f:read("*a")
    f:close()
    return text
  end)

  if not read_ok or not content or content == "" then
    _cache = {}
    return _cache
  end

  local decode_ok, decoded = pcall(vim.json.decode, content)
  if not decode_ok or type(decoded) ~= "table" then
    notify("[reposcope] Query stats file is corrupt or invalid JSON.", 4)
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
  safe_mkdir(fnamemodify(path, ":h"))

  local ok, encoded = pcall(vim.json.encode, _cache or {})
  if not ok then
    notify("[reposcope] Failed to encode query stats: " .. tostring(encoded), 4)
    return false
  end

  local write_ok, err = pcall(function()
    local f = assert(io.open(path, "w"))
    f:write(encoded)
    f:close()
  end)

  if not write_ok then
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
