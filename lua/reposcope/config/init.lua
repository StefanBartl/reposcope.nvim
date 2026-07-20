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

---@type ConfigOptions
M.options = require("reposcope.config.DEFAULTS")

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

  ---@type ConfigOptions
  M.options = vim.tbl_deep_extend("force", M.options, opts)

  -- Prompt fields must always be normalized
  set_prompt_fields(M.options.prompt_fields)
end

---Returns the current filecache directory
---@return string The current filecache directory
function M.get_readme_filecache_dir()
  return filecache_path .. "/readme"
end

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
      if vim.fn.isdirectory(expanded) == 1 then
        resolved = expanded
      end
    end

    if resolved == "" then
      local is_windows = require("reposcope.utils.os").is_windows()
      resolved = is_windows and (os.getenv("USERPROFILE") or "./") or (os.getenv("HOME") or "./")
    end

    --@type CloneOption
    local clone_result = {
      std_dir = resolved,
      type = M.options.clone.type,
    }
    return clone_result
  end

  if key == "logfile_path" then
    return logfile_path
  end

  if key == "cache_dir" then
    return filecache_path
  end

  return value
end

return M
