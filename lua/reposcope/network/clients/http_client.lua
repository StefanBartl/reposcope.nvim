---@class HTTPClient
---@field request fun(method: string, url: string, callback: fun(response: string|nil, error_msg?: string|nil), headers?: table, debug?: boolean, metrics_context?: string): nil Executes an HTTP request using curl and records metrics
local M = {}

local uv = vim.loop
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")

--- Sends an HTTP request using curl (asynchronous) with optional metrics
---@param method string HTTP method (GET, POST, PUT, DELETE)
---@param url string The URL for the HTTP request
---@param callback fun(response: string|nil, error_msg?: string|nil) Callback with the response or error
---@param headers? table Optional headers
---@param debug? boolean Optional debug flag
---@param metrics_context? string Optional context for metrics (e.g., "fetch_readme", "clone_repo")
function M.request(method, url, callback, headers, debug, metrics_context)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local response_data = {}
  local stderr_data = {}
  local uuid = metrics.generate_uuid()
  local start_time = vim.loop.hrtime()

  local curl_args = { "-s", "-X", method, url }

  -- Add headers to curl command
  if headers then
    for key, value in pairs(headers) do
      table.insert(curl_args, "-H")
      table.insert(curl_args, key .. ": " .. value)
    end
  end

  -- Initialize curl process
  local handle = uv.spawn("curl", {
    args = curl_args,
    stdio = { nil, stdout, stderr }
  }, function(code)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Calculate duration in milliseconds

    stdout:close()
    stderr:close()

    if code ~= 0 then
      if metrics_context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "http_client", metrics_context, duration_ms, code, "HTTP Request failed with code: " .. code)
      end
      callback(nil, "HTTP request failed with code: " .. code)
      return
    end
  end)

  if not handle then
    callback(nil, "Failed to start curl process")
    return
  end

  -- Read stdout (response content)
  stdout:read_start(function(err, data)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Calculate duration in milliseconds

    if err then
      if metrics_context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "http_client", metrics_context, duration_ms, 0, "Error reading stdout: " .. err)
      end
      callback(nil, "Error reading stdout: " .. err)
      return
    end

    if data then
      table.insert(response_data, data)
    else
      local response = table.concat(response_data)

      if metrics_context and metrics.record_metrics() then
        metrics.increase_success(uuid, url, "http_client", metrics_context, duration_ms, 200)
      end

      callback(response)
    end
  end)

  -- Read stderr (debugging information)
  stderr:read_start(function(err, data)
    if err then
      notify("[reposcope] Error reading curl stderr: " .. err, 4)
    elseif data and debug then
      notify("[reposcope] curl stderr data: " .. data, 1)
      table.insert(stderr_data, data)
    end
  end)
end

return M
