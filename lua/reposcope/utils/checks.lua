---@class ReposcopeChecks Utility functions for checking environment conditions and available binaries.
---@field has_binary fun(name: string): boolean Returns true if the given binary is executable on the system.
---@field first_available fun(binaries: string[]): string|nil Returns the first available binary from a list or nil if none found.
---@field resolve_request_tool fun(requesters?: string[]): nil Selects the preferred available request tool and sets it in config.
---@field has_env fun(name: string): boolean Returns true if the given environment variable is set and non-empty.
local M = {}

-- Configuration (Global Configuration)
local config = require("reposcope.config")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Checks if a given binary is available in the system's PATH
---@param name string The name of the binary to check
function M.has_binary(name)
  return vim.fn.executable(name) == 1
end

---Returns the first available binary from a list
---@param binaries string[] A list of binary names to check
function M.first_available(binaries)
  for _, bin in ipairs(binaries) do
    if M.has_binary(bin) then return bin end
  end
  return nil
end

---Resolves and sets the preferred request tool for Reposcope
---@param requesters? string[] Optional list of preferred request tools to use
function M.resolve_request_tool(requesters)
  requesters = requesters or config.options.preferred_requesters or { "gh", "curl", "wget" }

  local req_tool = M.first_available(requesters)
  if not req_tool then
    notify("[reposcope.nvim]: no request tool available", 4)
  else
    config.options.request_tool = req_tool
  end
end

---Checks if an environment variable is set and non-empty
---@param name string The name of the environment variable
function M.has_env(name)
  return vim.env[name] and #vim.env[name] > 0
end

return M
