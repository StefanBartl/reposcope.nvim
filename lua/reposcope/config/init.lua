---@module 'reposcope.config'
---@brief Handles the dynamic configuration setup and access for Reposcope.
---@description
--- This module manages the active configuration of Reposcope. It merges user-provided options
--- (via `.setup({ ... })`) with default values from `reposcope.config.DEFAULTS` and provides a
--- unified interface to access configuration values during runtime.
---
--- Key responsibilities:
--- - Validating and sanitizing `ConfigOptions`
--- - Providing a `setup()` entry point for user configuration
--- - Resolving nested default structures like `clone`, `keymaps`, etc.
--- - Allowing access to values via `get_option(key)` abstraction
--- - Computing fallback paths like `cache_dir` and `logfile_path`
---
--- The resulting `M.options` table is always fully populated and safe to use across modules.
--- Use `get_option(key)` instead of accessing `M.options` directly to preserve fallback logic.

---@class ReposcopeConfig : ReposcopeConfigModule
local M = {}

-- Utility Modules (Protection and Debugging)
local set_prompt_fields = require("reposcope.ui.prompt.prompt_config").set_fields

-- Deep-copied so this module never writes through to the `DEFAULTS` table
-- cached in `package.loaded` -- the env resolution below would otherwise
-- mutate the shared defaults themselves, and every future `require
-- ("reposcope.config.DEFAULTS")` would answer "what did this machine's
-- environment resolve to" instead of "what are the defaults".
---@type ConfigOptions
local defaults = vim.deepcopy(require("reposcope.config.DEFAULTS"))

-- Via lib.nvim's env snapshot, not env_get("REPOS_DIR"): it's the one
-- sanctioned place this specific env var is read, so it agrees with the
-- $REPOS_DIR Tab-completion keyword offered in bindings/usrcmds.lua. Resolved
-- here, not in DEFAULTS.lua, so requiring that module alone stays pure data
-- (LUA-06).
defaults.clone.std_dir = require("lib.nvim.system.env").get().repo_base or defaults.clone.std_dir

-- Same reason as `clone.std_dir` above: resolved here, not inline in
-- DEFAULTS.lua's table, so requiring that module alone stays pure data
-- (LUA-06).
local env_get = require("reposcope.utils.env").get
defaults.github_token = env_get("GITHUB_TOKEN") or defaults.github_token
defaults.gitlab_token = env_get("GITLAB_TOKEN") or defaults.gitlab_token
defaults.codeberg_token = env_get("CODEBERG_TOKEN") or defaults.codeberg_token

---@type ConfigOptions
M.options = vim.deepcopy(defaults)

---@private
---Root directory for cache and logs
local base_cache = vim.fn.stdpath("cache") .. "/reposcope"

---@private
---Persistent file-based cache directory
local filecache_path = base_cache .. "/data"

---@private
---Absolute path to the request log file
local logfile_path = base_cache .. "/logs/request_log.json"

---Setup function for configuration
---@param opts PartialConfigOptions|nil User configuration options
---@return nil
function M.setup(opts)
  if type(opts) ~= "table" and opts ~= nil then
    require("reposcope.utils.debug").notify("[reposcope] Ignoring config: expected table, got " .. type(opts), 4)
    opts = {}
  end

  -- Rebuilt from the pristine `defaults` on every call, not from the current
  -- `M.options` -- otherwise setup() accumulates across calls instead of
  -- applying `opts` on top of the defaults each time, and `setup({})` could
  -- never reset anything a previous call had set.
  ---@type ConfigOptions
  M.options = vim.tbl_deep_extend("force", {}, defaults, opts)

  -- Prompt fields must always be normalized
  set_prompt_fields(M.options.prompt_fields)
end

---Returns the current filecache directory
---@return string The current filecache directory
function M.get_readme_filecache_dir() return filecache_path .. "/readme" end

---Returns the absolute path of the README freshness-metadata file
---@return string
function M.get_readme_meta_path() return filecache_path .. "/readme_meta.json" end

---Returns the absolute path of the persisted session file
---@return string
function M.get_session_path() return filecache_path .. "/session.json" end

---Returns the absolute path of the persisted favorites file
---@return string
function M.get_favorites_path() return filecache_path .. "/favorites.json" end

---Returns the absolute path of the persisted query-frequency file
---@return string
function M.get_query_stats_path() return filecache_path .. "/query_stats.json" end

---@param key ConfigOptionKey
---@return any
function M.get_option(key)
  assert(key ~= nil, "config.get_option: key must be provided")
  local value = M.options[key]

  if key == "request_tool" then
    return (value ~= "" and value) or "curl" -- curl as fallback
  end

  if key == "clone" then
    local dir = M.options.clone.std_dir
    local resolved = ""

    if dir and dir ~= "" then
      local expanded = require("lib.nvim.cross.fs.expand_path")(dir)
      if vim.fn.isdirectory(expanded) == 1 then resolved = expanded end
    end

    if resolved == "" then
      local is_windows = require("reposcope.utils.os").is_windows()
      resolved = is_windows and (os.getenv("USERPROFILE") or "./") or (os.getenv("HOME") or "./")
    end

    ---@type CloneOptions
    local clone_result = {
      std_dir = resolved,
      type = M.options.clone.type,
    }
    return clone_result
  end

  if key == "logfile_path" then return logfile_path end

  if key == "cache_dir" then return filecache_path end

  return value
end

return M
