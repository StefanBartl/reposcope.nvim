---@module 'reposcope.network.request_tools.wget'
---@brief Executes HTTP requests using the `wget` CLI.
---@description
--- This module provides an asynchronous wrapper around performing HTTP GET requests
--- using the `wget` command-line tool. It supports header injection, debug output,
--- and response piping using Neovim's `uv.spawn`. Unlike `curl`, it only supports GET.
--- It is a low-level utility used internally for network access in Reposcope.

---@class WgetRequest : WgetRequestModule
local M = {}

-- libuv
local uv = vim.uv or vim.loop
-- Async spawn+capture (delegates the pipe/timer/handle bookkeeping)
local spawn_capture = require("lib.nvim.cross.uv.spawn_capture")

-- Utilities
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")

---Issues a WGET request asynchronously and returns the response via callback
---@param method string Only "GET" is supported
---@param url string Full URL to request
---@param callback fun(response: string|nil, err?: string): nil
---@param _headers? table<string, string> Ignored in current implementation (wget has limited header support)
---@param debug? boolean Enables verbose stderr output
---@param context? string Optional metrics label
---@param uuid? string Optional unique request identifier
---@return nil
function M.request(method, url, callback, _headers, debug, context, uuid)
  if method ~= "GET" then
    callback(nil, "wget only supports GET method")
    return
  end

  local start_time = uv.hrtime()
  local safe_uuid = uuid or "n/a"
  local safe_context = context or "unspecified"

  local args = {
    "--quiet",
    "--output-document=-", -- write to stdout
    url,
  }

  notify("[reposcope] WGET Request: wget " .. table.concat(args, " "), vim.log.levels.TRACE)

  local argv = { "wget" }
  for _, a in ipairs(args) do argv[#argv + 1] = a end

  spawn_capture(argv, {}, function(result)
    local duration = (uv.hrtime() - start_time) / 1e6

    if debug and result.stderr ~= "" then
      notify("[reposcope] wget stderr: " .. result.stderr, vim.log.levels.TRACE)
    end

    if not result.ok then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "wget", safe_context, duration, result.code, "wget error")
      end
      callback(nil, "wget request failed (code " .. result.code .. ")")
    else
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "wget", safe_context, duration, 200)
      end
      callback(result.stdout)
    end
  end)
end

return M
