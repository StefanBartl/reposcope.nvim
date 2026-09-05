---@module 'reposcope.network.request_tools.gh'
---@brief Executes GitHub CLI (`gh`) requests with metrics and async callback support.
---@description
--- Provides a wrapper around the GitHub CLI for issuing API requests.
--- Supports injecting headers, capturing metrics, error logging, and debug output.
--- It is designed to be used internally by GitHub-based fetch modules.
--- This is a low-level utility and does not format or interpret the response.

---@class GitHubRequest : GithubRequestModule
local M = {}

-- SEC-21: see curl.lua's own note -- spawn_capture's timeout_ms is opt-in,
-- and this module never passed one either. Same 20s default for the same
-- reason (a JSON API call or a README fetch, not a large download).
local DEFAULT_TIMEOUT_MS = 20000

-- libuv Utilities
local hrtime = vim.uv.hrtime
-- Async spawn+capture (delegates the pipe/timer/handle bookkeeping)
local spawn_capture = require("lib.nvim.cross.uv.spawn_capture")
-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")
local config = require("reposcope.config")

---Issues a GitHub CLI API request and returns the response to callback
---@param method string HTTP method (e.g. "GET", "POST")
---@param url string Full GitHub API URL (e.g. "https://api.github.com/repos/user/repo/readme")
---@param callback fun(response: string|nil, err?: string): nil Callback that receives the API response or error
---@param headers? table<string, string> Optional request headers
---@param debug? boolean Enable verbose CLI output and stderr capture
---@param context? string Optional metrics label (e.g. "fetch_readme")
---@param uuid? string Optional unique identifier for request tracking
---@return nil
function M.request(method, url, callback, headers, debug, context, uuid)
  local start_time = hrtime()
  local safe_uuid = uuid or "n/a"
  local safe_context = context or "unspecified"

  local token = config.options.github_token
  local parsed = url:gsub("^https://api%.github%.com", "")
  local args = { "api", parsed, "--method", method }

  -- Add headers. `redacted` mirrors `args` with credential values replaced,
  -- and it is what the log and the notify below are built from: gh normally
  -- authenticates through GITHUB_TOKEN in the environment, but `headers` is
  -- caller-supplied and an Authorization header there would otherwise be
  -- written to disk verbatim.
  local curl_secrets = require("lib.nvim.net.curl")
  local redacted = { "api", parsed, "--method", method }
  for k, v in pairs(headers or {}) do
    args[#args + 1] = "--header"
    args[#args + 1] = k .. ": " .. v
    redacted[#redacted + 1] = "--header"
    redacted[#redacted + 1] = k .. ": " .. (curl_secrets.is_secret_header(k) and "<redacted>" or v)
  end

  -- Debug CLI output
  if debug then
    table.insert(args, "--verbose")
    table.insert(redacted, "--verbose")
  end

  -- Only when asked. This used to append on every single request, so the file
  -- grew without bound whether or not anyone had turned debugging on.
  if debug then
    local debug_path = vim.fn.stdpath("cache") .. "/reposcope/logs/gh-debug.txt"
    require("lib.nvim.fs.write.append")(debug_path, "GH Request: gh " .. table.concat(redacted, " "))
  end

  -- Completed env (PATH + session/keyring vars) as the "KEY=VALUE" array
  -- spawn_capture's libuv-backed spawn expects; see reposcope.utils.spawn_env.
  -- GITHUB_TOKEN is layered on top so an explicit config token always wins.
  local vars = nil
  if token and token ~= "" then vars = { GITHUB_TOKEN = token } end
  local env = require("reposcope.utils.spawn_env").array(vars)

  notify("[reposcope] GH Request: gh " .. table.concat(redacted, " "), 2)

  local argv = { "gh" }
  for _, a in ipairs(args) do
    argv[#argv + 1] = a
  end

  spawn_capture(argv, { env = env, timeout_ms = DEFAULT_TIMEOUT_MS }, function(result)
    local duration = (hrtime() - start_time) / 1e6 -- ms

    if not result.ok then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "gh", safe_context, duration, result.code, "gh CLI error", url)
      end
      -- Dev level, not error: the failure travels back through `callback`, and
      -- it is the caller that knows whether it matters. A 404 from a README
      -- probe is routine (many repositories have none) and used to raise an
      -- error message per keypress while walking the list. `curl` and `wget`
      -- already report through the callback alone.
      if result.timed_out then
        notify("[reposcope] gh timed out after " .. DEFAULT_TIMEOUT_MS .. "ms", 2)
        callback(nil, "gh request timed out after " .. DEFAULT_TIMEOUT_MS .. "ms")
      else
        notify("[reposcope] gh exited with code " .. result.code, 2)
        notify("[reposcope] stderr: " .. result.stderr, 2)
        callback(nil, "gh request failed (code " .. result.code .. ")")
      end
    else
      if debug and result.stderr ~= "" then notify("[reposcope] gh stderr: " .. result.stderr, 4) end
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "gh", safe_context, duration, 200, url)
      end
      callback(result.stdout)
    end
  end)
end

return M
