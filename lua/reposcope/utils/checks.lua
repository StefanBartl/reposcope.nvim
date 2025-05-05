--- @class ReposcopeChecks Utility functions for checking environment conditions and available binaries.
--- @field has_binary fun(name: string): boolean Returns true if the given binary is executable on the system.
--- @field first_available fun(binaries: string[]): string|nil Returns the first available binary from a list or nil if none found.
--- @field resolve_request_tool fun(requesters?: string[]): nil Selects the preferred available request tool and sets it in config.
--- @field has_env fun(name: string): boolean Returns true if the given environment variable is set and non-empty.
local M = {}

local config = require("reposcope.config")

function M.has_binary(name)
  return vim.fn.executable(name) == 1
end

function M.first_available(binaries)
  for _, bin in ipairs(binaries) do
    if M.has_binary(bin) then return bin end
  end
  return nil
end

function M.resolve_request_tool(requesters)
  requesters = requesters or config.options.preferred_requesters or { "gh", "curl", "wget" }

  local req_tool = M.first_available(requesters)
  if not req_tool then
    vim.notify("[reposcope.nvim]: no request tool available", vim.log.levels.ERROR)
  else
    config.options.request_tool = req_tool
end

end

function M.has_env(name)
  return vim.env[name] and #vim.env[name] > 0
end

return M
