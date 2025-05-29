---@modul 'curl_request'
---@class CurlRequest
---@brief Executes HTTP requests using the `curl` CLI.
---@description
--- This module provides an asynchronous wrapper for performing HTTP requests
--- using the `curl` command-line tool. It supports header injection, metrics
--- tracking, debug output, and response piping via Neovim's `uv.spawn`.
--- It is a low-level utility for network access and is used by fetchers.

-- System Module
local uv = vim.loop

-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")

local M = {}

---Issues a CURL request asynchronously and returns the response via callback
---@param method string HTTP method to use (e.g. "GET", "POST")
---@param url string Target URL for the request
---@param callback fun(response: string|nil, err?: string): nil Callback that receives response or error
---@param headers? table<string, string> Optional HTTP headers
---@param debug? boolean Enables verbose stderr logging
---@param context? string Optional label for metrics (e.g. "fetch_readme")
---@param uuid? string Optional unique identifier for request tracking
---@return nil
---@raises string if curl spawn fails or if output pipes fail
function M.request(method, url, callback, headers, debug, context, uuid)
  local start_time = uv.hrtime()
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local safe_uuid = uuid or "n/a"
  local safe_context = context or "unspecified"
  local response_data = {}

  local args = { "-s", "-X", method, url }
  for k, v in pairs(headers or {}) do
    table.insert(args, "-H")
    table.insert(args, k .. ": " .. v)
  end

  notify(string.format("[reposcope] CURL Request: curl %s", table.concat(args, " ")), vim.log.levels.TRACE)

  local handle = uv.spawn("curl", {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(code)
 ---@diagnostic disable-next-line: undefined-field
    stdout:close()
  ---@diagnostic disable-next-line: undefined-field
    stderr:close()

    local duration = (uv.hrtime() - start_time) / 1e6 -- ms

    if code ~= 0 then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "curl", safe_context, duration, code, "curl error")
      end
      callback(nil, "curl request failed (code " .. code .. ")")
    else
      callback(table.concat(response_data))
    end
  end)

  if not handle then
    callback(nil, "Failed to spawn curl")
    return
  end

  ---@diagnostic disable-next-line: undefined-field
  stdout:read_start(function(err, data)
    local duration_ms = (uv.hrtime() - start_time) / 1e6

    if err then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "curl", safe_context, duration_ms, 0, "Error reading curl stdout: " .. err)
      end
      callback(nil, "curl stdout error: " .. err)
      return
    end

    if data then
      table.insert(response_data, data)
    else
      local response = table.concat(response_data)
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "curl", safe_context, duration_ms, 200)
      end
      callback(response)
    end
  end)

  ---@diagnostic disable-next-line: undefined-field
  stderr:read_start(function(err, data)
    local duration_ms = (uv.hrtime() - start_time) / 1e6

    if err then
      if context and metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "curl", context, duration_ms, 0, "Error reading curl stderr: " .. err)
      end
      notify(string.format("[reposcope] curl stderr read error: %s", err), vim.log.levels.ERROR)
      return
    end

    if debug and data then
      notify(string.format("[reposcope] curl stderr: %s", data), vim.log.levels.TRACE)
    end
  end)
end

return M
