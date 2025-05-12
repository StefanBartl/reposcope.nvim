---@class ReposcopeConfig
---@field options ConfigOptions Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field get_cache_dir fun(): string Returns the current cache path
---@field get_clone_dir fun(): string Returns the standard clone directory
---@field get_log_path fun(): string|nil Check if log options are set and returns it
---@field init_cache_dir fun(): nil Initialize cache path
---@field init_log_path fun(): nil Initialize log path for persistent log files
local M = {}

local protection = require("reposcope.utils.protection")
local debug = require("reposcope.utils.debug")

---@class CloneOptions 
---@field std_dir string Standardth for cloning repositories
---@field type string Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)

--- Configuration options for Reposcope
---@class ConfigOptions
---@field provider string The API provider to be used (default: "github")
---@field preferred_requesters string[] List of preferred tools for making HTTP requests (default: {"gh", "curl", "wget"})
---@field request_tool string Default request tool (default: "gh")
---@field github_token string  Github authorization token (for higher request limits)
---@field results_limit number Maximum number of results returned in search queries (default: 25)
---@field preview_limit number Maximum number of lines shown in preview (default: 200)
---@field layout string UI layout type (default: "default")
---@field cache_dir string Path for Reposcope cache data (default: OS-dependent) 
---@field log_format string Log format ("json" or "xml")
---@field log_filepath string Full path to the log file (determined dynamically)
---@field log_max number Controls the size of the log file
---@field clone CloneOptions Options to configure cloning repositories
M.options = {
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  github_token = "", -- Github authorization token (for higher request limits)
  results_limit = 25, -- Default result limit for search queries
  preview_limit = 200, -- Default preview limit for displayed results
  layout = "default", -- Default UI layout
  clone = {
    std_dir = "~/temp",  -- Standard path for cloning repositories
    type = "", -- Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)
  },
  -- Only change following values if you fully understand the impact; incorrect values may cause incomplete data or plugin crashes.
  cache_dir = "", -- Cache path for persistent cache files; standard is: vim.fn.stdpath("cache") .. "/reposcope/data"
  log_filepath = "", -- Full path (without .ext) to the log file; standard is: vim.fn.stdpath("cache") .. "/reposcope/logs/log"
  log_format = "json", -- Log format ("json" or "xml")
  log_max = 1000, -- Controls the size of the log file
}

---Setup function for configuration
---@param opts ConfigOptions User configuration options
function M.setup(opts)
  -- Merge user-provided options with default options
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})

  -- Set the clone type based on the request tool
  M.options.clone.type = M.options.clone.type ~= "" and M.options.clone.type or M.options.request_tool

  M.init_cache_dir()
  M.init_log_path()
end

---Returns the current cache path
---@return string The current cache path
function M.get_cache_dir()
  return M.options.cache_dir
end

--- Initialize cache path for persistent cached data
function M.init_cache_dir()
  if M.options.cache_dir and M.options.cache_dir ~= "" then
    M.options.cache_dir = vim.fn.expand(M.options.cache_dir)
    if not protection.is_valid_path(M.options.cache_dir, false) then
      M.options.cache_dir = vim.fn.stdpath("cache") .. "/reposcope/data"
    end
  else
    M.options.cache_dir = vim.fn.stdpath("cache") .. "/reposcope/data"
  end

  if not protection.safe_mkdir(M.options.cache_dir) then
    debug.notify("[reposcope] Cache path could not be created: " .. M.options.cache_dir, 4)
  end
end


---Check if log options are set and return them
function M.get_log_path()
  if not M.options.log_filepath or M.options.log_filepath == "" then
    require("reposcope.utils.debug").notify("[reposcope] No log file path set. No logging possible", 3)
    return nil
  end

  return M.options.log_filepath .. "." .. M.options.log_format
end


---Initialize log path for persistent log files
function M.init_log_path()

  -- Check if the user has set a custom log file path
  if M.options.log_filepath and M.options.log_filepath ~= "" then
    local log_filepath = M.get_log_path() or ""
    if protection.is_valid_path(log_filepath, true) then
      return
    else
      debug.notify("[reposcope] Warning: User-defined log path is invalid. Falling back to default.", 3)
    end
  end

  -- Use default log path if user-defined path is invalid or not set
  local log_dir = vim.fn.stdpath("cache") .. "/reposcope/logs"
  protection.safe_mkdir(log_dir)
  M.options.log_filepath = vim.fn.fnameescape(log_dir .. "/request_log." .. M.options.log_format)

  if not protection.is_valid_path(M.options.log_filepath, true) then
    debug.notify("[reposcope] Error: Log file path could not be set or is invalid.", 4)
  end
end

---Returns the standard directory for cloning
function M.get_clone_dir()
  if M.options.clone.std_dir ~= "" and M.options.clone.std_dir and vim.fn.isdirectory(M.options.clone.std_dir) then
    return M.options.clone.std_dir
  else
    local is_windows = vim.loop.os_uname().sysname:match("Windows")
    if is_windows then
      return os.getenv("USERPROFILE") or "./"
    else
      return os.getenv("HOME") or "./"
    end
  end
end

return M
