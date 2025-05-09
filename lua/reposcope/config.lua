---@class ReposcopeConfig
---@field options ConfigOptions Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field is_debug_mode fun(): boolean Checks if debug mode is enabled
---@field get_state_path fun(): string Returns the current state path
---@field get_cache_path fun(): string Returns the current cache path
---@field toggle_dev_mode fun(): nil Toggle dev mode (standard: false)
---@field toggle_debug_mode fun(): nil Toggle debug mode (standard: false)
---@field get_clone_dir fun(): string Returns the standard clone directory
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
---@field dev_mode boolean Enables developer mode (default: false)
---@field debug_mode boolean Enables debug mode (default: false)
---@field g_state_path string Path for Reposcope state data (default: OS-dependent)
---@field g_cache_path string Path for Reposcope cache data (default: OS-dependent)
---@field clone CloneOptions Options to configure cloning repositories
M.options = {
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  github_token = "", -- Github authorization token (for higher request limits)
  results_limit = 25, -- Default result limit for search queries
  preview_limit = 200, -- Default preview limit for displayed results
  layout = "default", -- Default UI layout
  dev_mode = false, -- Developer mode flag
  debug_mode = false, -- Debug mode flag
  g_state_path = "", -- Path for Reposcope state data
  g_cache_path = "", -- Cache path, determined in setup
  clone = {
    std_dir = "~/temp",  -- Standard path for cloning repositories
    type = "wget", -- Tool for cloning repositories (choose 'curl' or 'wget' for .zip repositories)
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
  M.options.g_cache_path = vim.fn.fnameescape(
    (M.options.g_cache_path ~= "" and M.options.g_cache_path) or (M.options.g_state_path .. "/cache")
  )
end

---Checks if dev mode is enabled
function M.is_dev_mode()
  return M.options.dev_mode
end

---Checks if debug mode is enabled
function M.is_debug_mode()
  return M.options.debug_mode
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

---Toggle dev mode config option 
function M.toggle_dev_mode()
  M.options.dev_mode = not M.options.dev_mode
end

---Toggle debug mode config option
function M.toggle_debug_node()
   M.options.debug_mode = not M.options.debug_mode
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

return M
