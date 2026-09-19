-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/query_stats_spec.lua — the persisted search-frequency counters behind
-- `:Reposcope queries`. Runs against a fixture file, with
-- `config.get_query_stats_path` redirected before the module is loaded.

return function(H)
  local dir, cleanup = H.fixture("query_stats")
  local path = dir .. "/query_stats.json"

  local config = require("reposcope.config")
  local saved_path_fn = config.get_query_stats_path
  config.get_query_stats_path = function() return path end

  local function reload()
    package.loaded["reposcope.state.query_stats"] = nil
    return require("reposcope.state.query_stats")
  end

  local ok, err = pcall(function()
    -------------------------------------------------------------------------
    -- Nothing recorded yet
    -------------------------------------------------------------------------
    local stats = reload()
    H.eq(next(stats.load()), nil, "a missing file loads as an empty table")
    H.eq(#stats.top(10), 0, "with no top queries")

    -------------------------------------------------------------------------
    -- Recording
    -------------------------------------------------------------------------
    stats.record("neovim plugin")
    stats.record("neovim plugin")
    stats.record("telescope")
    H.eq(stats.load()["neovim plugin"], 2, "a repeated query is counted twice")
    H.eq(stats.load()["telescope"], 1, "and a single one once")
    H.ok(vim.fn.filereadable(path) == 1, "the counts are persisted immediately")

    -- Nothing meaningful to record must not create a phantom entry.
    stats.record("")
    stats.record(nil)
    stats.record(42)
    H.eq(vim.tbl_count(stats.load()), 2, "an empty or non-string query records nothing")

    -------------------------------------------------------------------------
    -- Ranking
    -------------------------------------------------------------------------
    stats.record("zzz")
    stats.record("aaa")
    local top = stats.top(10)
    H.eq(top[1].query, "neovim plugin", "the most frequent query comes first")
    H.eq(top[1].count, 2, "with its count")
    -- Ties are broken alphabetically, so the list does not reshuffle between
    -- two runs that recorded the same thing.
    H.eq(top[2].query, "aaa", "ties are broken alphabetically, ascending")
    H.eq(top[3].query, "telescope", "so the order is stable across runs")
    H.eq(top[4].query, "zzz", "all the way down")

    H.eq(#stats.top(2), 2, "top(n) returns at most n")
    H.eq(#stats.top(0), 0, "top(0) returns nothing")
    H.eq(#stats.top(100), 4, "and asking for more than exists returns what there is")

    -------------------------------------------------------------------------
    -- Persistence across sessions
    -------------------------------------------------------------------------
    local reloaded = reload()
    H.eq(reloaded.load()["neovim plugin"], 2, "the counts survive a fresh load")
    reloaded.record("neovim plugin")
    H.eq(reloaded.load()["neovim plugin"], 3, "and keep accumulating from where they were")

    -------------------------------------------------------------------------
    -- A corrupt file is reported, backed up, and stepped over
    -------------------------------------------------------------------------
    vim.fn.writefile({ "{not json" }, path)
    local corrupt_path = path .. ".corrupt"
    vim.fn.delete(corrupt_path)

    local corrupt = reload()
    H.eq(next(corrupt.load()), nil, "a corrupt file loads as empty rather than raising")
    H.ok(vim.fn.filereadable(corrupt_path) == 1, "corrupt file was backed up to query_stats.json.corrupt")
    H.eq(H.read(corrupt_path), "{not json", "backup preserves the original corrupt bytes")

    corrupt.record("fresh start")
    H.eq(corrupt.load()["fresh start"], 1, "and recording still works afterwards")

    -------------------------------------------------------------------------
    -- Clearing
    -------------------------------------------------------------------------
    corrupt.clear_all()
    H.eq(next(corrupt.load()), nil, "clear_all empties the counters")
    H.eq(#corrupt.top(5), 0, "with nothing left to rank")
    H.eq(next(reload().load()), nil, "and the empty state is what the next session reads")
  end)

  config.get_query_stats_path = saved_path_fn
  package.loaded["reposcope.state.query_stats"] = nil
  cleanup()
  if not ok then error(err, 0) end
end
