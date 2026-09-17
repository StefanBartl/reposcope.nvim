-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/config_options_spec.lua — `config.get_option()`'s computed answers.
--
-- `config_spec.lua` covers the merge; this covers the four keys that are not
-- a plain table lookup (`request_tool`, `clone`, `logfile_path`, `cache_dir`)
-- and the derived cache paths every persistence module builds on.

return function(H)
  local config = require("reposcope.config")
  local dir, cleanup = H.fixture("config_options")

  local ok, err = pcall(function()
    -------------------------------------------------------------------------
    -- A key is mandatory
    -------------------------------------------------------------------------
    local ok_nil, err_nil = pcall(config.get_option, nil)
    H.falsy(ok_nil, "get_option(nil) is a programming error, and says so")
    H.contains(tostring(err_nil), "key must be provided", "with a message that names the problem")

    H.eq(config.get_option("no_such_option"), nil, "an unknown key is simply nil")

    -------------------------------------------------------------------------
    -- request_tool: never empty
    -------------------------------------------------------------------------
    local saved_tool = config.options.request_tool
    config.options.request_tool = "wget"
    H.eq(config.get_option("request_tool"), "wget", "a configured tool is returned as-is")
    config.options.request_tool = ""
    H.eq(config.get_option("request_tool"), "curl", "an empty one falls back to curl, not to nothing")
    config.options.request_tool = saved_tool

    -------------------------------------------------------------------------
    -- clone: the std_dir is resolved, and always to something usable
    -------------------------------------------------------------------------
    local saved_clone = vim.deepcopy(config.options.clone)

    config.options.clone.std_dir = dir
    config.options.clone.type = "gh"
    local clone = config.get_option("clone")
    H.eq(type(clone), "table", "clone resolves to a table")
    H.eq(clone.std_dir, dir, "an existing directory is used verbatim")
    H.eq(clone.type, "gh", "the configured tool comes along")

    -- The returned table is built fresh, so a caller mutating it cannot
    -- corrupt the stored configuration.
    clone.std_dir = "/mutated"
    H.eq(config.options.clone.std_dir, dir, "and the result is a copy, not the live option table")

    -- A directory that does not exist is not silently accepted: the home
    -- directory is used instead, so a clone always has somewhere to go.
    local home = require("reposcope.utils.os").is_windows() and os.getenv("USERPROFILE") or os.getenv("HOME")
    config.options.clone.std_dir = dir .. "/definitely-missing"
    H.eq(config.get_option("clone").std_dir, home or "./", "a missing directory falls back to the user's home")

    config.options.clone.std_dir = ""
    H.eq(config.get_option("clone").std_dir, home or "./", "so does an empty one")

    config.options.clone = saved_clone

    -------------------------------------------------------------------------
    -- The computed paths
    -------------------------------------------------------------------------
    local cache_dir = config.get_option("cache_dir")
    H.ok(type(cache_dir) == "string" and cache_dir ~= "", "cache_dir resolves to a path")
    H.contains(cache_dir, "reposcope", "under the plugin's own cache root")

    local logfile = config.get_option("logfile_path")
    H.contains(logfile, "reposcope", "the request log lives under the same root")
    H.contains(logfile, "request_log.json", "and is the file data.nvim can read")

    -- Every persisted file is a sibling inside the same data directory, so
    -- clearing that one directory clears all plugin state.
    local paths = {
      readme = config.get_readme_filecache_dir(),
      readme_meta = config.get_readme_meta_path(),
      session = config.get_session_path(),
      favorites = config.get_favorites_path(),
      query_stats = config.get_query_stats_path(),
    }
    for name, path in pairs(paths) do
      H.eq(path:sub(1, #cache_dir), cache_dir, name .. " lives inside cache_dir")
    end
    H.contains(paths.readme_meta, "readme_meta.json", "the freshness sidecar is named for what it holds")
    H.contains(paths.session, "session.json", "as is the session file")
    H.contains(paths.favorites, "favorites.json", "the favorites file")
    H.contains(paths.query_stats, "query_stats.json", "and the query-frequency file")

    -- `cache_dir` is a constant computed once at load; `get_option` must not
    -- start answering differently because someone set an option of that name.
    config.setup({ cache_dir = "/not/this" })
    H.eq(config.get_option("cache_dir"), cache_dir, "a user cannot override the computed cache directory by that name")
    config.options.cache_dir = nil

    -------------------------------------------------------------------------
    -- setup() normalizes the prompt fields as a side effect
    -------------------------------------------------------------------------
    local prompt_config = require("reposcope.ui.prompt.prompt_config")
    local saved_fields = vim.deepcopy(prompt_config.get_fields())

    config.setup({ prompt_fields = { "keywords", "owner", "keywords", "nonsense", "prefix" } })
    local fields = prompt_config.get_fields()
    H.eq(fields[1], "prefix", "`prefix` is pulled to the front, wherever it was configured")
    H.eq(#fields, 3, "duplicates are dropped and invalid names are ignored")
    H.eq(table.concat(fields, ","), "prefix,keywords,owner", "and the surviving order is the configured one")

    config.setup({ prompt_fields = saved_fields })
  end)

  cleanup()
  if not ok then error(err, 0) end
end
