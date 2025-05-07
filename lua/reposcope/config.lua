---@class ReposcopeConfig
---@field options table<string, any> Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field is_debug_mode fun(): boolean Checks if debug mode is enabled
local M = {}

---Detects and sets the correct state path based on the OS
---Uses the detected OS in the system state to determine the default path
---@return string The state path for Reposcope
local function set_state_path()
  if require("reposcope.state.system").os == "unix" then
    return vim.fn.expand("~/.local/state/nvim/reposcope")
  else
    return vim.fn.expand("~/AppData/Local/nvim-data/reposcope")
  end
end

---Default configuration options
M.options = {
  provider = "github", -- Default provider for Reposcope (GitHub)
  preferred_requesters = { "gh", "curl", "wget" }, -- Preferred tools for API requests
  request_tool = "gh", -- Default request tool (GitHub CLI)
  results_limit = 25, -- Default result limit for search queries
  preview_limit = 200, -- Default preview limit for displayed results
  layout = "default", -- Default UI layout
  dev_mode = false, -- Developer mode flag
  debug_mode = false, -- Debug mode flag
  g_state_path = nil, -- Path for Reposcope state data
  g_cache_path = nil, -- Cache path, determined in setup
}

---Setup function for configuration
---@param opts table User configuration options
function M.setup(opts)
  -- Merge user-provided options with default options
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})

  -- Set and ensure the state path is properly set
  M.options.g_state_path = vim.fn.fnameescape(
    M.options.g_state_path or set_state_path()
  )
  M.options.g_cache_path = vim.fn.fnameescape(
    M.options.g_cache_path or (M.options.g_state_path .. "/cache")
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

return M
