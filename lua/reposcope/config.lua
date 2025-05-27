---REF: outsource functions to /config_utils

---@alias ConfigOptionKey
---| "provider"
---| "preferred_requesters"
---| "request_tool"
---| "github_token"
---| "results_limit"
---| "preview_limit"
---| "layout"
---| "clone"
---| "keymaps"
---| "keymap_opts"
---| "metrics"
---| "cache_dir"
---| "log_filepath"
---| "log_max"

---@class ReposcopeConfig
---@field options ConfigOptions Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field get_cache_dir fun(): string Returns the current cache path  REF: get_option
---@field get_clone_dir fun(): string Returns the standard clone directory  REF: get_option
---@field get_log_path fun(): string|nil Check if log options are set and returns it REF: get_option
---@field get_option fun(key: ConfigOptionKey): any Returns a specific value from config.options, with optional fallback
local M = {}

local init_cache_dir, init_log_path, sanitize_opts

-- Utility Modules (Protection and Debugging)
local protection = require("reposcope.utils.protection")
local notify = require("reposcope.utils.debug").notify
local defaults = require("reposcope.defaults").options

---@class CloneOptions 
---@field std_dir string Standardth for cloning repositories
---@field type string Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)


--NOTE: maybe private and acces only via setter and getter ?

--- Configuration options for Reposcope
---@class ConfigOptions
---@field provider string The API provider to be used (default: "github")
---@field preferred_requesters string[] List of preferred tools for making HTTP requests (default: {"gh", "curl", "wget"})
---@field request_tool string Default request tool (default: "gh")
---@field github_token string  Github authorization token (for higher request limits)
---@field results_limit number Maximum number of results returned in search queries (default: 25)
---@field preview_limit number Maximum number of lines shown in preview (default: 200)
---@field layout string UI layout type (default: "default")
---@field clone CloneOptions Options to configure cloning repositories
---@field keymaps table<string, string> Set keymaps to open and close Reposcope
---@field keymap_opts table Set keymap options
---@field metrics boolean Controls the state to record metrics
---@field cache_dir string Path for Reposcope cache data (default: OS-dependent) 
---@field log_filepath string Full path to the log file (determined dynamically)
---@field log_max number Controls the size of the log file
M.options = {
  provider = "", -- Default provider for Reposcope (GitHub)
  preferred_requesters = {}, -- Preferred tools for API requests
  request_tool = "", -- Default request tool (GitHub CLI)
  github_token = "", -- Github authorization token (for higher request limits)
  results_limit = 0, -- Default result limit for search queries
  preview_limit = 0, -- Default preview limit for displayed results
  layout = "", -- Default UI layout
  clone = {
    std_dir = "",  -- Standard path for cloning repositories
    type = "", -- Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)
  },
  keymaps = { -- NOTE: Other keymaps?
    open = "<leader>rs",  -- Set the keymap to open Repsocope
    close = "<leader>rc",  -- Set the keymap to close Reposcope
  },
  keymap_opts = {
    silent = true,  -- Silent option for open and close keymap
    noremap = true,  -- noremap option for open and close keymap
  },

  -- Only change the following values in your setup({}) if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  metrics = false,
  cache_dir = "", -- Cache path for persistent cache files; standard is: vim.fn.stdpath("cache") .. "/reposcope/data"
  log_filepath = "", -- Full path (without .ext) to the log file; standard is: vim.fn.stdpath("cache") .. "/reposcope/logs/log"
  log_max = 0, -- Controls the size of the log file
}

---Setup function for configuration
---@param opts ConfigOptions User configuration options
function M.setup(opts)
  local sanitized = sanitize_opts(opts or {})

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

  init_cache_dir()
  init_log_path()
end

function M.get_readme_fcache_dir()
  local filecache = M.get_cache_dir()
  return filecache .. "/readme"
end


---Returns the current cache path
---@return string The current cache path
function M.get_cache_dir()
  return M.options.cache_dir
end


---@private
--- Initialize cache path for persistent cached data
function init_cache_dir()
  if M.options.cache_dir and M.options.cache_dir ~= "" then
    M.options.cache_dir = vim.fn.expand(M.options.cache_dir)
    if not protection.is_valid_path(M.options.cache_dir, false) then
      M.options.cache_dir = vim.fn.stdpath("cache") .. "/reposcope/data"
    end
  else
    M.options.cache_dir = vim.fn.stdpath("cache") .. "/reposcope/data"
  end

  if not protection.safe_mkdir(M.options.cache_dir) then
    notify("[reposcope] Cache path could not be created: " .. M.options.cache_dir, 4)
  end
end


---Check if log options are set and return them
function M.get_log_path()
  if not M.options.log_filepath or M.options.log_filepath == "" then
    require("reposcope.utils.debug").notify("[reposcope] No log file path set. No logging possible", 3)
    return nil
  end

  return M.options.log_filepath .. ".json"
end

---@private
---Initialize log path
function init_log_path()

  -- Check if the user has set a custom log file path
  if M.options.log_filepath and M.options.log_filepath ~= "" then
    local log_filepath = M.get_log_path() or ""
    if protection.is_valid_path(log_filepath, true) then
      return
    else
      notify("[reposcope] Warning: User-defined log path is invalid. Falling back to default.", 3)
    end
  end

  -- Use default log path if user-defined path is invalid or not set
  local log_dir = vim.fn.stdpath("cache") .. "/reposcope/logs"
  protection.safe_mkdir(log_dir)
  M.options.log_filepath = vim.fn.fnameescape(log_dir .. "/request_log")

  if not protection.is_valid_path(M.options.log_filepath, true) then
    notify("[reposcope] Error: Log file path could not be set or is invalid.", 4)
  end

  local log_file = M.get_log_path()
  if not log_file then
      notify("[reposcope] Log file path could not be determined", 4)
  else
      if not vim.fn.filereadable(log_file) then
          local file, err = io.open(log_file, "w")
          if err then
              notify("[reposcope] Log file could not be created: " .. err, 4)
          elseif file then
              io.close(file)
          end
      end
  end

end

---Returns the standard directory for cloning
function M.get_clone_dir()
  if M.options.clone.std_dir ~= "" and M.options.clone.std_dir and vim.fn.isdirectory(M.options.clone.std_dir) then
    return M.options.clone.std_dir
  else
    ---@diagnostic disable-next-line vim.loop or vim.uv os_uname exists
    local is_windows = vim.loop.os_uname().sysname:match("Windows")
    if is_windows then
      return os.getenv("USERPROFILE") or "./"
    else
      return os.getenv("HOME") or "./"
    end
  end
end


--- Returns a specific value from config.options, with optional fallback.
--- If `request_tool` is empty, returns `"curl"` instead.
---@param key ConfigOptionKey
---@return any
function M.get_option(key)
  local value = M.options[key]

  if key == "request_tool" then
    return (value ~= "" and value) or "curl" -- curl as fallback
  end

  if key == "clone" then
    local clone = {}
    clone.std_dir = M.get_clone_dir()
    clone.type = M.options.clone.type
    return clone
  end

  if key == "log_filepath" then
    return M.get_log_path()
  end

  if key == "cache_dir" then
    return M.get_cache_dir()
  end

  return value
end



---@private
--- Sanitizes user-provided options: removes empty strings and unknown fields.
--- Dynamically derives valid fields from defaults.options
---@param opts table
---@return table
function sanitize_opts(opts)
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
