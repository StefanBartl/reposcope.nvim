---@class ReposcopeConfig
---@field options table<string, any> Configuration options for Reposcope
---@field setup fun(opts: table): nil Setup function for user configuration
---@field is_dev_mode fun(): boolean Checks if developer mode is enabled
---@field is_debug_mode fun(): boolean Checks if debug mode is enabled
local M = {}

---Default configuration options
M.options = {
  provider = "github",
  preferred_requesters = { "gh", "curl", "wget" },
  request_tool = "gh",
  results_limit = 25, -- Github search api can return max 100 results without pagination
  preview_limit = 200,
  layout = "default",
  dev_mode = false,
  debug_mode = false,
}

---Setup function for configuration
---@param opts table User configuration options
function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", M.options, opts or {})
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
