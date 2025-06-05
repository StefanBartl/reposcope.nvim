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

-- Utility Modules (Protection and Debugging)
local set_prompt_fields = require("reposcope.ui.prompt.prompt_config").set_fields
-- ENV-VAR Utility
local env_get = require("reposcope.utils.env").get

---@type ConfigOptions
M.options = {
  prompt_fields = { "prefix", "keywords", "owner", "language" }, -- Default fields for the prompt in the UI
  provider = "github",                                           -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" },               -- Preferred tools for API requests
  request_tool = "gh",                                           -- Default request tool (GitHub CLI)
  github_token = env_get("GITHUB_TOKEN") or "",                  -- Github authorization token (for higher request limits)
  results_limit = 25,                                            -- Default result limit for search queries
  layout = "default",                                            -- Default UI layout
  clone = {
    std_dir = "~/temp",                                          -- Standard path for cloning repositories
    type = "",                                                   -- Tool for cloning repositories (choose curl' or 'wget' for .zip repositories. 'gh' is possible. Default is 'git'.)
  },
  keymaps = {
    open = "<leader>rs",  -- Set the keymap to open Repsocope
    close = "<leader>rc", -- Set the keymap to close Reposcope
  },
  keymap_opts = {
    silent = true,  -- Silent option for open and close keymap
    noremap = true, -- noremap option for open and close keymap
  },

  -- Only change the following values in your setup({}) if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  metrics = false,
  log_max = 1000, -- Controls the size of the log file
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

return M
