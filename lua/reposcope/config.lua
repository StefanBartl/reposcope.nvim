---@class ReposcopeConfig
---@field options ConfigOptions Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field get_state_path fun(): string Returns the current state path
---@field get_cache_path fun(): string Returns the current cache path
---@field get_clone_dir fun(): string Returns the standard clone directory
---@field get_log_path fun(): string|nil Check if log options are set and returns it
local M = {}

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
---@field g_state_path string Path for Reposcope state data (default: OS-dependent)
---@field g_cache_path string Path for Reposcope cache data (default: OS-dependent) 
---@field log_format string Log format ("json" or "xml")
---@field log_file string Full path to the log file (determined dynamically)
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
  g_state_path = "", -- Path for Reposcope state data
  g_cache_path = "", -- Cache path, determined in setup
  log_format = "json", -- Log format ("json" or "xml")
  log_file = "", -- Full path to the log file (determined dynamically)
  log_max = 1000, -- Controls the size of the log file
  clone = {
    std_dir = "~/temp",  -- Standard path for cloning repositories
    type = "", -- Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)
  }
}

---Setup function for configuration
---@param opts ConfigOptions User configuration options
function M.setup(opts)
  -- Merge user-provided options with default options
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})

  -- Set the clone type based on the request tool
  M.options.clone.type = M.options.clone.type ~= "" and M.options.clone.type or M.options.request_tool

  -- Set and ensure the state path is properly set
  M.options.g_state_path = vim.fn.fnameescape(
    (M.options.g_state_path ~= "" and M.options.g_state_path) or vim.fn.expand("~/.local/state/nvim/reposcope") --NOTE: not win conform
  )

  -- Set the cache path
  M.options.g_cache_path = vim.fn.fnameescape(
    (M.options.g_cache_path ~= "" and M.options.g_cache_path) or (M.options.g_state_path .. "/cache")
  )

  -- Set the log file path dynamically based on format
  local path_check =  require("reposcope.utils.protection").is_valid_path
  if not M.options.log_file or not path_check(M.options.log_file, false) then
    M.options.log_file = vim.fn.fnameescape(M.options.g_state_path .. "/request_log." .. M.options.log_format)
  end

  -- Debugging: Ausgabe des gesetzten Pfads
  if not path_check(M.options.log_file, true) then
    require("reposcope.utils.debug").notify("[reposcope] Error: Log file path could not be set or is invalid.", vim.log.levels.ERROR)
  end
end

---Returns the current state path
---@return string The current state path
function M.get_state_path()
  return M.options.g_state_path
end

---Returns the current cache path
---@return string The current cache path
function M.get_cache_path()
  return M.options.g_cache_path
end

---DEBUG: branches
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

---Check if log options are set and return them
function M.get_log_path()
  -- Bedingung korrekt formuliert: Pfad muss existieren und darf nicht leer sein
  if not M.options.log_file or M.options.log_file == "" then
    require("reposcope.utils.debug").notify("[reposcope] No log file path set. No logging possible", vim.log.levels.WARN)
    return nil
  end

  return M.options.log_file
end

return M
