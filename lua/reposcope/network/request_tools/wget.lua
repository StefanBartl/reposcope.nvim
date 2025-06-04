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

  local _ = _headers
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local start_time = uv.hrtime()
  local safe_uuid = uuid or "n/a"
  local safe_context = context or "unspecified"
  local response_data = {}
  local stderr_data = {}

  local args = {
    "--quiet",
    "--output-document=-", -- write to stdout
    url,
  }

  notify("[reposcope] WGET Request: wget " .. table.concat(args, " "), vim.log.levels.TRACE)

  local handle = uv.spawn("wget", {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(code)
    ---@diagnostic disable-next-line
    stdout:close()
    ---@diagnostic disable-next-line
    stderr:close()

    local duration = (uv.hrtime() - start_time) / 1e6

    if code ~= 0 then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "wget", safe_context, duration, code, "wget error")
      end
      callback(nil, "wget request failed (code " .. code .. ")")
    else
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "wget", safe_context, duration, 200)
      end
      callback(table.concat(response_data))
    end
  end)

  if not handle then
    callback(nil, "Failed to spawn wget CLI")
    return
  end

  ---@diagnostic disable-next-line
  stdout:read_start(function(err, data)
    if err then
      callback(nil, "wget stdout error: " .. err)
      return
    end
    if data then
      table.insert(response_data, data)
    end
  end)

  ---@diagnostic disable-next-line
  stderr:read_start(function(err, data)
    if err then
      notify("[reposcope] wget stderr read error: " .. err, vim.log.levels.ERROR)
      return
    end
    if debug and data then
      table.insert(stderr_data, data)
      notify("[reposcope] wget stderr: " .. data, vim.log.levels.TRACE)
    end
  end)
end

return M
