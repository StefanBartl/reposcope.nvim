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
---Delegates to lib.nvim.core.has_exec, which memoizes the result per binary
---name (this module's own version re-checked vim.fn.executable every call).
---@param name string The name of the binary to check
---@return boolean available True if the binary is executable in PATH
function M.has_binary(name) return require("lib.nvim.core").has_exec(name) end

---Returns the first available binary from a list
---@param binaries string[] A list of binary names to check
---@return string|nil available_binary The name of the first available binary, or nil if none found
function M.first_available(binaries) return require("lib.nvim.core").first_available(binaries) end

---Resolves and sets the preferred request tool for Reposcope.
---Uses user config, fallback list, and system availability to set a valid requester.
---@param requesters? string[] Optional list of preferred request tools to use (e.g. { "gh", "curl", "wget" })
---@return boolean ok True if a usable request tool is set in config.options.request_tool
---@return string? err Set only when `ok` is false
function M.resolve_request_tool(requesters)
  requesters = requesters or config.options.preferred_requesters or { "gh", "curl", "wget" }
  local req_tool = config.options.request_tool or nil

  -- Check if there is a requester tool set as request_tool and its available on the system
  if req_tool and tbl_find(requesters, req_tool) and M.has_binary(req_tool) then return true end

  local new_req_tool = M.first_available(requesters)
  if not new_req_tool then
    -- Nothing to switch to: the configured value (if any) is left in place
    -- rather than nil'd, so a later error still names a tool. The caller is
    -- told resolution failed either way (ERR-03) -- this also covers a
    -- configured-but-not-installed tool with nothing else available, which
    -- used to fail silently because the check below tested `req_tool`
    -- instead of `new_req_tool`.
    local err = "no request tool available"
    notify("[reposcope.nvim]: " .. err, 4)
    return false, err
  end

  config.options.request_tool = new_req_tool
  return true
end

return M
