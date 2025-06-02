---@module 'reposcope.config'
---@brief Handles the dynamic configuration setup and access for Reposcope.
---@description
--- This module manages the active configuration of Reposcope. It merges user-provided options
--- (via `.setup({ ... })`) with default values from `reposcope.defaults` and provides a unified
--- interface to access configuration values during runtime.
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

---@description Forward declarations for private functions
local _sanitize_opts

-- Utility Modules (Protection and Debugging)
local defaults = require("reposcope.defaults").options
local set_prompt_fields = require("reposcope.ui.prompt.prompt_config").set_fields

---@type ConfigOptionKey[]
M.options = {
  prompt_fields = {},        -- Default fields for the prompt in the UI
  provider = "",             -- Default provider for Reposcope (GitHub)
  preferred_requesters = {}, -- Preferred tools for API requests
  request_tool = "",         -- Default request tool (GitHub CLI)
  github_token = "",         -- Github authorization token (for higher request limits)
  results_limit = 0,         -- Default result limit for search queries
  ---@type LayoutType
  layout = "",               -- Default UI layout
  clone = {
    std_dir = "",            -- Standard path for cloning repositories
    type = "",               -- Tool for cloning repositories (choose curl' or 'wget' for .zip repositories. 'gh' is possible. Default is 'git'.)
  },
  keymaps = {
    open = "",  -- Set the keymap to open Repsocope
    close = "", -- Set the keymap to close Reposcope
  },
  keymap_opts = {
    silent = true,  -- Silent option for open and close keymap
    noremap = true, -- noremap option for open and close keymap
  },

  -- Only change the following values in your setup({}) if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  metrics = false,
  log_max = 0, -- Controls the size of the log file
}

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
function M.setup(opts)
  local sanitized = _sanitize_opts(opts or {})

  -- Merges configuration in three priority levels:
  -- 1. Base: `defaults.options` provides standard fallback values.
  -- 2. Middle: `M.options` (values from config.lua) are preserved where set and not overwritten by defaults.
  -- 3. Highest: User-provided `opts` via `.setup({ ... })` override both.
  -- This guarantees safe defaults, respects values declared in `config.lua`,
  -- and allows users to override any setting via setup().
  ---@type ConfigOptions
  M.options = vim.tbl_deep_extend("force",
    vim.tbl_deep_extend("keep", {}, defaults, M.options or {}),
    sanitized
  )

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

    if dir ~= "" and dir and vim.fn.isdirectory(dir) then
      resolved = dir
    else
      ---@diagnostic disable-next-line vim.loop or vim.uv os_uname exists
      local is_windows = vim.loop.os_uname().sysname:match("Windows")
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


---@private
--- Sanitizes user-provided options: removes empty strings and unknown fields.
--- Dynamically derives valid fields from defaults.options
---@param opts table
---@return table
function _sanitize_opts(opts)
  local options = M.options
  if type(opts) ~= "table" then return {} end

  local clean = {}

  for key, value in pairs(opts) do
    local default_value = options[key]

    -- Only allow fields that exist in defaults
    if default_value ~= nil and value ~= nil and value ~= "" then
      if type(value) == "table" and type(default_value) == "table" then
        -- Clean nested tables (shallow clone only)
        local nested = {}
        for k, v in pairs(value) do
          if v ~= nil and v ~= "" then
            nested[k] = v
          end
        end
        clean[key] = nested
      else
        clean[key] = value
      end
    end
  end

  return clean
end

return M
