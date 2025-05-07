---@class API
---@field request fun(method: string, url: string, callback: fun(response: string|nil), headers?: table, debug?: boolean): nil Sends an API request using HTTP module
local M = {}

local http = require("reposcope.utils.http")
local metrics = require("reposcope.utils.metrics")
local notify = require("reposcope.utils.debug").notify

 ---Sends a generalized API request (GET, POST, etc.)
---@param method string The HTTP method (e.g., GET, POST)
---@param url string The URL for the API request
---@param callback fun(response: string|nil) Callback with the response data or nil on failure
---@param headers? table Optional headers for the request
---@param debug? boolean Optional debug flag for debugging output
function M.request(method, url, callback, headers, debug)
  -- Extract source from URL (for better logging)
  local source = url:match("https://api%.github%.com/([^/?]+)") or "unknown"
  local query = url:match("%?q=([^&]+)") or "none"
  local start_time = vim.loop.hrtime() -- Start time for duration calculation

  -- Increase request counter and check rate limit
  metrics.increase_req(query, source)
  metrics.check_rate_limit()

  -- Build HTTP request with headers (if provided)
  local request_headers = headers or {}
  if debug then
    request_headers["Debug"] = "true"
  end

  -- Check if the method is supported (currently only GET)
  if method ~= "GET" then
    vim.schedule(function()
      notify("[reposcope] Unsupported HTTP method: " .. method, vim.log.levels.ERROR)
    end)
    metrics.increase_failed(query, source, 0, 405, "Method Not Allowed")
    callback(nil)
    return
  end

  -- Send HTTP request
  http.get(url, function(response)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Calculate duration in milliseconds
    if response then
      metrics.increase_success(query, source, duration_ms, 200)
      callback(response)
    else
      metrics.increase_failed(query, source, duration_ms, 500, "Request failed")
      callback(nil)
    end
  end, debug)
end

--- Convenience functions for specific methods
function M.get(url, callback, headers, debug)
  M.request("GET", url, callback, headers, debug)
end

function M.post(url, callback, headers, debug)
  M.request("POST", url, callback, headers, debug)
end

function M.put(url, callback, headers, debug)
  M.request("PUT", url, callback, headers, debug)
end

function M.delete(url, callback, headers, debug)
  M.request("DELETE", url, callback, headers, debug)
end

return M
