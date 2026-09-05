---@module 'reposcope.network.request_tools.curl_request'
---@brief Executes HTTP requests using the `curl` CLI.
---@description
--- This module provides an asynchronous wrapper for performing HTTP requests
--- using the `curl` command-line tool. It supports header injection, metrics
--- tracking, debug output, and response piping via Neovim's `uv.spawn`.
--- It is a low-level utility for network access and is used by fetchers.

---@class CurlRequest : CurlRequestModule
local M = {}

-- SEC-21: spawn_capture's timeout_ms is opt-in ("no timer means no timeout"),
-- and this module never passed one -- every search/README/API request the
-- plugin makes could hang indefinitely on a stalled connection or an
-- unresponsive host, with no way for the plugin to give up and report
-- failure. 20s is generous for a JSON API call or a README fetch; it is not
-- meant to bound a large download (this module isn't used for one).
local DEFAULT_TIMEOUT_MS = 20000

-- libuv Utilities
local hrtime = vim.uv.hrtime
-- Async spawn+capture (delegates the pipe/timer/handle bookkeeping)
local spawn_capture = require("lib.nvim.cross.uv.spawn_capture")
local curl_secrets = require("lib.nvim.net.curl")
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

  -- A credential-bearing header goes into a curl config fed on stdin (`-K -`),
  -- never into argv: a process's command line is readable by any other process
  -- on the machine (`ps`, Win32_Process), so an `-H "Authorization: …"` there
  -- is public for the lifetime of the request.
  local args = { "-s", "-X", method, url }
  local config, redacted = {}, {}
  for k, v in pairs(headers or {}) do
    if curl_secrets.is_secret_header(k) then
      config[#config + 1] = "header = " .. curl_secrets.config_quote(k .. ": " .. v)
      redacted[#redacted + 1] = "-H " .. k .. ": <redacted>"
    else
      table.insert(args, "-H")
      table.insert(args, k .. ": " .. v)
      redacted[#redacted + 1] = "-H " .. k .. ": " .. v
    end
  end

  -- The log line is built from `redacted`, not `args`: this used to print the
  -- full command including the Authorization header, and :messages is the
  -- first thing that gets pasted into a bug report.
  notify("[reposcope] CURL Request: curl " .. table.concat(args, " ") .. " " .. table.concat(redacted, " "), 1)

  local argv = { "curl" }
  if #config > 0 then
    argv[#argv + 1] = "-K"
    argv[#argv + 1] = "-"
  end
  for _, a in ipairs(args) do
    argv[#argv + 1] = a
  end

  -- Completed env (PATH + session/keyring vars) — curl's stored credentials
  -- (.netrc, cookie jars) depend on HOME/session vars just as much as gh does.
  local env = require("reposcope.utils.spawn_env").array()

  local stdin = #config > 0 and (table.concat(config, "\n") .. "\n") or nil

  spawn_capture(argv, { env = env, stdin = stdin, timeout_ms = DEFAULT_TIMEOUT_MS }, function(result)
    local duration = (hrtime() - start_time) / 1e6 -- ms

    if debug and result.stderr ~= "" then notify("[reposcope] curl stderr: " .. result.stderr, 4) end

    if not result.ok then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "curl", safe_context, duration, result.code, "curl error", url)
      end
      if result.timed_out then
        callback(nil, "curl request timed out after " .. DEFAULT_TIMEOUT_MS .. "ms")
      else
        callback(nil, "curl request failed (code " .. result.code .. ")")
      end
    else
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "curl", safe_context, duration, 200, url)
      end
      callback(result.stdout)
    end
  end)
end

return M
