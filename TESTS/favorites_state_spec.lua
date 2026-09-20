-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/favorites_state_spec.lua — persisted favorites: load/toggle, and
-- that a corrupt favorites.json is backed up rather than silently discarded.

return function(H)
  local dir, cleanup = H.fixture("favorites_state")
  local favorites_path = dir .. "/favorites.json"

  local config = require("reposcope.config")
  local original_get_path = config.get_favorites_path
  config.get_favorites_path = function() return favorites_path end

  local function reload()
    package.loaded["reposcope.state.favorites_state"] = nil
    package.loaded["reposcope.cache.readme_cache"] = package.loaded["reposcope.cache.readme_cache"] or nil
    return require("reposcope.state.favorites_state")
  end

  local ok, err = pcall(function()
    -- Toggle on / off ----------------------------------------------------------
    local favs = reload()
    local repo = {
      owner = { login = "nvim-telescope" },
      name = "telescope.nvim",
      description = "Find files",
      html_url = "https://github.com/nvim-telescope/telescope.nvim",
      default_branch = "master",
      stargazers_count = 100,
    }

    H.falsy(favs.is_favorite("nvim-telescope", "telescope.nvim"), "not a favorite yet")
    local now_fav = favs.toggle(repo)
    H.ok(now_fav, "toggle() reports true when adding")
    H.ok(favs.is_favorite("nvim-telescope", "telescope.nvim"), "is_favorite() sees the addition")
    H.eq(#favs.list(), 1, "one persisted favorite")

    local now_unfav = favs.toggle(repo)
    H.falsy(now_unfav, "toggle() reports false when removing")
    H.falsy(favs.is_favorite("nvim-telescope", "telescope.nvim"), "is_favorite() sees the removal")

    -- Corrupt file is backed up, not silently discarded -------------------------
    favs.toggle(repo) -- re-add, so there is something real to lose
    H.eq(#favs.list(), 1, "one favorite persisted before corrupting the file")

    vim.fn.writefile({ "{not valid json" }, favorites_path)
    local corrupt_path = favorites_path .. ".corrupt"
    vim.fn.delete(corrupt_path)

    favs = reload()
    local loaded = favs.load()
    H.eq(type(loaded), "table", "corrupt file loads as a table, not an error")
    H.eq(#loaded, 0, "corrupt file loads as empty, not a crash")
    H.ok(vim.fn.filereadable(corrupt_path) == 1, "corrupt file was backed up to favorites.json.corrupt")
    H.eq(H.read(corrupt_path), "{not valid json", "backup preserves the original corrupt bytes")

    -- The bug this guards against: toggling now must not have silently
    -- destroyed the corrupt file without a trace -- it already is backed up
    -- above, and the very next toggle only has to not error out.
    favs.toggle(repo)
    H.eq(#favs.list(), 1, "toggling after a corrupt load still works and persists")

    -- A later load() while the file is still corrupt must not clobber an
    -- existing backup with a second, possibly different one (LLS-31: the
    -- backup write itself is a plain io.open/file:write, whose failure is a
    -- nil/false return rather than a Lua error, so only a real check of the
    -- handle and the write result -- not a bare pcall around them -- would
    -- ever have caught it not firing here).
    vim.fn.writefile({ "{different corruption" }, favorites_path)
    favs = reload()
    favs.load()
    H.eq(H.read(corrupt_path), "{not valid json", "the first backup survives a second corrupt load")
    vim.fn.delete(corrupt_path)

    -- An empty file is not "corrupt" -- nothing to report, nothing to back
    -- up (same as cache.readme_cache's freshness sidecar).
    vim.fn.writefile({}, favorites_path)
    favs = reload()
    local empty_loaded = favs.load()
    H.eq(type(empty_loaded), "table", "an empty file loads as a table, not an error")
    H.eq(#empty_loaded, 0, "and as empty")
    H.eq(vim.fn.filereadable(corrupt_path), 0, "no backup slot is consumed for it")
  end)

  config.get_favorites_path = original_get_path
  package.loaded["reposcope.state.favorites_state"] = nil
  cleanup()

  if not ok then error(err, 0) end
end
