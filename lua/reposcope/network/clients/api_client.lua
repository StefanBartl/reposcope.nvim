---@class API
---@field request fun(method: string, url: string, callback: fun(response: string|nil, error?: string|nil), headers?: table, context?: string): nil Sends an API request using HTTP module
local M = {}

-- HTTP Client (Low-level HTTP Requests)
local http_client = require("reposcope.network.clients.http_client")
-- Utility Modules (Debugging)
local notify = require("reposcope.utils.debug").notify


local active_requests = {}


---Sends a generalized API request (GET, POST, etc.)
---@param method string The HTTP method (e.g., GET, POST)
---@param url string The URL for the API request
---@param callback fun(response: string|nil, error?: string|nil) Callback with the response data or error message
---@param headers? table Optional headers for the request
---@param context? string Optional context identifier (e.g., "fetch_repo", "fetch_readme", "clone_repo")
function M.request(method, url, callback, headers, context)
  -- Set default context if not provided
  context = context or "general"

  -- Check if there is a currently running request ongoing
  if active_requests[url] then
    notify("[reposcope] Request already in progress for URL: " .. url, 3)
    return
  end

  active_requests[url] = true

  -- Send HTTP request using the HTTP client
  http_client.request(method, url, function(response, error)
    active_requests[url] = nil

    if error then
      callback(nil, error)
      return
    end

    callback(response, nil)
  end, headers)
end

return M
