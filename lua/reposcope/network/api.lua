---@class API
---@field request fun(method: string, url: string, callback: fun(response: string|nil), headers?: table, debug?: boolean, context?: string): nil Sends an API request using HTTP module
local M = {}

local http = require("reposcope.network.http")
local metrics = require("reposcope.utils.metrics")
local notify = require("reposcope.utils.debug").notify
local generate_uuid = require("reposcope.utils.metrics").generate_uuid
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

  local uuid = generate_uuid()
  -- Prüfen, ob bereits eine aktive Anfrage für diesen Kontext läuft
  if active_requests[uuid] then
    notify("[reposcope] Request already in progress for context: " .. context, 3)
    return
  end

  active_requests[uuid] = true

  -- Extract source from URL (for better logging)
  local source
  if url:match("https://api%.github%.com/") then
    source = url:match("https://api%.github%.com/([%w_]+)/") or "unknown"
    if source == "search" then
      source = "search_api"
    elseif source == "repos" then
      source = "core_api"
    end
  elseif url:match("https://raw%.githubusercontent%.com/") then
    source = "raw"
  elseif url:match("^git clone") or url:match("^gh repo clone") then
    source = "clone"
  elseif url:match("^curl") or url:match("^wget") then
    source = "clone_download"
  else
    source = "unknown"
  end


  local query = url:match("q=([^&]+)") or "none"

  local start_time = vim.loop.hrtime() -- Start time for duration calculation

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
