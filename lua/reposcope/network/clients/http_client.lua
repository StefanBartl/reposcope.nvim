---@module 'reposcope.network.clients.http_client'
---@brief Central HTTP request dispatcher for all supported tools
---@description
--- This module provides a unified interface to dispatch HTTP requests
--- using different CLI tools (`gh`, `curl`, `wget`). It injects authorization
--- headers when needed and routes requests to the appropriate implementation
--- in `request_tools`. It also supports debugging and metric context tracking.

---@class HTTPClient
local M = {}

-- Vim Utilities
local tbl_extend = vim.tbl_extend
-- Provider modules
local gh = require("reposcope.network.request_tools.gh")
local curl = require("reposcope.network.request_tools.curl")
local wget = require("reposcope.network.request_tools.wget")
-- Debug and Config dependencies
local notify = require("reposcope.utils.debug").notify
local get_option = require("reposcope.config").get_option


---@private
---Builds the Authorization header based on tool and token
---@param token string GitHub token from config
---@param tool string The selected request tool ("gh", "curl", "wget")
---@return table<string, string> Authorization headers (or empty)
local function _build_auth_header(token, tool)
  if type(token) ~= "string" or token == "" then return {} end
  if tool == "curl" or tool == "wget" then
    return { ["Authorization"] = "Bearer " .. token }
  elseif tool == "gh" then
    return {} -- gh uses env
  end
  return {}
end


---Dispatches a request using the appropriate CLI tool backend
---@param method string HTTP method (e.g. "GET", "POST")
---@param url string Full URL to request
---@param callback fun(response: string|nil, error_msg?: string|nil) Called with response or error
---@param headers? table<string, string> Optional HTTP headers
---@param debug? boolean Enable debug output
---@param metrics_context? string Optional metrics context identifier
---@return nil
function M.request(method, url, callback, headers, debug, metrics_context)
  if type(url) ~= "string" or url == "" then
    callback(nil, nil) -- Silent error to clear preview window
    return
  end

  local uuid = require("reposcope.utils.core").generate_uuid()
  local request_module
  local default_tool = get_option("request_tool")
  local default_token = get_option("github_token")

  if default_tool == "gh" then
    request_module = gh
  elseif default_tool == "curl" then
    request_module = curl
  elseif default_tool == "wget" then
    request_module = wget
  else
    notify("[reposcope] Unknown request default_tool: " .. tostring(default_tool), 4)
    callback(nil, "Unsupported request default_tool")
    return
  end

  local auth_headers = _build_auth_header(default_token, default_tool)
  headers = tbl_extend("force", headers or {}, auth_headers)

  request_module.request(method, url, callback, headers, debug, metrics_context, uuid)
end

return M

