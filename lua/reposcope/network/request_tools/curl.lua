---@module 'reposcope.network.request_tools.curl_request'
---@brief Executes HTTP requests using the `curl` CLI.
---@description
--- This module provides an asynchronous wrapper for performing HTTP requests
--- using the `curl` command-line tool. It supports header injection, metrics
--- tracking, debug output, and response piping via Neovim's `uv.spawn`.
--- It is a low-level utility for network access and is used by fetchers.

---@class CurlRequest : CurlRequestModule
local M = {}

-- libuv Utilities
local hrtime = vim.uv.hrtime
-- Async spawn+capture (delegates the pipe/timer/handle bookkeeping)
local spawn_capture = require("lib.nvim.cross.uv.spawn_capture")
-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")


---Issues a CURL request asynchronously and returns the response via callback
---@param method string HTTP method to use (e.g. "GET", "POST")
---@param url string Target URL for the request
---@param callback fun(response: string|nil, err?: string): nil Callback that receives response or error
---@param headers? table<string, string> Optional HTTP headers
---@param debug? boolean Enables verbose stderr logging
---@param context? string Optional label for metrics (e.g. "fetch_readme")
---@param uuid? string Optional unique identifier for request tracking
---@return nil
function M.request(method, url, callback, headers, debug, context, uuid)
  local start_time = hrtime()
  local safe_uuid = uuid or "n/a"
  local safe_context = context or "unspecified"

  local args = { "-s", "-X", method, url }
  for k, v in pairs(headers or {}) do
    table.insert(args, "-H")
    table.insert(args, k .. ": " .. v)
  end

  notify("[reposcope] CURL Request: curl " .. table.concat(args, " "), 1)

  local argv = { "curl" }
  for _, a in ipairs(args) do argv[#argv + 1] = a end

  spawn_capture(argv, {}, function(result)
    local duration = (hrtime() - start_time) / 1e6 -- ms

    if debug and result.stderr ~= "" then
      notify("[reposcope] curl stderr: " .. result.stderr, 4)
    end

    if not result.ok then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "curl", safe_context, duration, result.code, "curl error")
      end
      callback(nil, "curl request failed (code " .. result.code .. ")")
    else
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "curl", safe_context, duration, 200)
      end
      callback(result.stdout)
    end
  end)
end

return M
