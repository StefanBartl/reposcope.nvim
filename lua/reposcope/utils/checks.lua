---@module 'reposcope.utils.checks'
---@brief Checks Utility module for Reposcope

---@class ReposcopeChecks : ReposcopeChecksModule
local M = {}

-- Configuration (Global Configuration)
local config = require("reposcope.config")
-- Debugging and Utils
local notify = require("reposcope.utils.debug").notify
local tbl_find = require("reposcope.utils.core").tbl_find

---Checks if a given binary is available in the system's PATH
---@param name string The name of the binary to check
---@return boolean available True if the binary is executable in PATH
function M.has_binary(name)
  return vim.fn.executable(name) == 1
end

---Returns the first available binary from a list
---@param binaries string[] A list of binary names to check
---@return string|nil available_binary The name of the first available binary, or nil if none found
function M.first_available(binaries)
  local has = M.has_binary

  for i = 1, #binaries do
    local bin = binaries[i]
    if has(bin) then
      return bin
    end
  end

  return nil
end

---Resolves and sets the preferred request tool for Reposcope.
---Uses user config, fallback list, and system availability to set a valid requester.
---@param requesters? string[] Optional list of preferred request tools to use (e.g. { "gh", "curl", "wget" })
---@return nil
function M.resolve_request_tool(requesters)
  requesters = requesters or config.options.preferred_requesters or { "gh", "curl", "wget" }
  local req_tool = config.options.request_tool or nil

  -- Check if there is a requester tool set as request_tool and its available on the system
  if req_tool and tbl_find(requesters, req_tool) and M.has_binary(req_tool) then
    return
  end

  local new_req_tool = M.first_available(requesters)
  if not req_tool then
    notify("[reposcope.nvim]: no request tool available", 4)
  elseif new_req_tool then
    config.options.request_tool = new_req_tool
  end
end

return M
