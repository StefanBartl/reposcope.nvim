---@desc forward declaration
local set_state_path

---@class ReposcopeConfig
---@field options ConfigOptions Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field is_debug_mode fun(): boolean Checks if debug mode is enabled
---@field get_state_path fun(): string Returns the current state path
---@field get_cache_path fun(): string Returns the current cache path
local M = {}

--- Configuration options for Reposcope
---@class ConfigOptions
---@field provider string The API provider to be used (default: "github")
---@field preferred_requesters string[] List of preferred tools for making HTTP requests (default: {"gh", "curl", "wget"})
---@field request_tool string Default request tool (default: "gh")
---@field results_limit number Maximum number of results returned in search queries (default: 25)
---@field preview_limit number Maximum number of lines shown in preview (default: 200)
---@field layout string UI layout type (default: "default")
---@field dev_mode boolean Enables developer mode (default: false)
---@field debug_mode boolean Enables debug mode (default: false)
---@field g_state_path string Path for Reposcope state data (default: OS-dependent)
---@field g_cache_path string Path for Reposcope cache data (default: OS-dependent)
M.options = {
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  results_limit = 25, -- Default result limit for search queries
  preview_limit = 200, -- Default preview limit for displayed results
  layout = "default", -- Default UI layout
  dev_mode = false, -- Developer mode flag
  debug_mode = false, -- Debug mode flag
  g_state_path = "", -- Path for Reposcope state data
  g_cache_path = "", -- Cache path, determined in setup
}

---Setup function for configuration
---@param opts ConfigOptions User configuration options
function M.setup(opts)
  -- Merge user-provided options with default options
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})

  -- Set and ensure the state path is properly set
  M.options.g_state_path = vim.fn.fnameescape(
    (M.options.g_state_path ~= "" and M.options.g_state_path) or set_state_path()
  )
  M.options.g_cache_path = vim.fn.fnameescape(
    (M.options.g_cache_path ~= "" and M.options.g_cache_path) or (M.options.g_state_path .. "/cache")
  )
end

---Detects and sets the correct state path based on the OS
---Uses the detected OS in the system state to determine the default path
---@return string The state path for Reposcope
function set_state_path()
  if require("reposcope.state.system").os == "unix" then
    return vim.fn.expand("~/.local/state/nvim/reposcope")
  else
    return vim.fn.expand("~/AppData/Local/nvim-data/reposcope")
  end
end

---Checks if dev mode is enabled
function M.is_dev_mode()
  return M.options.dev_mode
end

---Checks if debug mode is enabled
function M.is_debug_mode()
  return M.options.debug_mode
end

---Gets the current state path
---@return string The current state path
function M.get_state_path()
  return M.options.g_state_path
end

---Gets the current cache path
---@return string The current cache path
function M.get_cache_path()
  return M.options.g_cache_path
end

return M
