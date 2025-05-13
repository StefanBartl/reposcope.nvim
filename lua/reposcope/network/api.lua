---@class API
---@field request fun(method: string, url: string, callback: fun(response: string|nil), headers?: table, debug?: boolean, context?: string): nil Sends an API request using HTTP module
local M = {}

local http = require("reposcope.network.http")
local notify = require("reposcope.utils.debug").notify
local active_requests = {}

---Sends a generalized API request (GET, POST, etc.)
---@param method string The HTTP method (e.g., GET, POST)
---@param url string The URL for the API request
---@param callback fun(response: string|nil) Callback with the response data or nil on failure
---@param headers? table Optional headers for the request
---@param debug? boolean Optional debug flag for debugging output
---@param context? string Optional context identifier (e.g., "fetch_repo", "fetch_readme", "clone_repo")
function M.request(method, url, callback, headers, debug, context)
  -- Set default context if not provided
  context = context or "general"

  -- Prüfen, ob bereits eine aktive Anfrage für diese URL läuft
  if active_requests[url] then
    notify("[reposcope] Request already in progress for URL: " .. url, 3)
    return
  end

  -- Markiere URL als aktiv
  active_requests[url] = true

  -- Build HTTP request with headers (if provided)
  local request_headers = headers or {}
  if debug then
    request_headers["Debug"] = "true"
  end

  -- Check if the method is supported (currently only GET)
  if method ~= "GET" then
    vim.schedule(function()
      notify("[reposcope] Unsupported HTTP method: " .. method, 4)
    end)
    callback(nil)
    return
  end

  -- Send HTTP request
  http.get(url, function(response)
    -- Callback und active_requests nur einmal freigeben
    if not active_requests[url] then return end
    active_requests[url] = nil

    if response then
      callback(response)
    else
      callback(nil)
    end
  end, debug)
end

--- Convenience functions for specific methods
function M.get(url, callback, headers, debug, context)
  M.request("GET", url, callback, headers, debug, context)
end

function M.post(url, callback, headers, debug, context)
  M.request("POST", url, callback, headers, debug, context)
end

function M.put(url, callback, headers, debug, context)
  M.request("PUT", url, callback, headers, debug, context)
end

function M.delete(url, callback, headers, debug, context)
  M.request("DELETE", url, callback, headers, debug, context)
end

return M

