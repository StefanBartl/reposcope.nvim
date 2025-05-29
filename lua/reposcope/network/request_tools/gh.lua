---@module 'gh_request'
---@class GitHubRequest
---@brief Executes GitHub CLI (`gh`) requests with metrics and async callback support.
---@description
--- Provides a wrapper around the GitHub CLI for issuing API requests.
--- Supports injecting headers, capturing metrics, error logging, and debug output.
--- It is designed to be used internally by GitHub-based fetch modules.
--- This is a low-level utility and does not format or interpret the response.

-- System API
local uv = vim.uv or vim.loop

-- Utilities and Debugging
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")
local config = require("reposcope.config")

local M = {}

---Issues a GitHub CLI API request and returns the response to callback
---@param method string HTTP method (e.g. "GET", "POST")
---@param url string Full GitHub API URL (e.g. "https://api.github.com/repos/user/repo/readme")
---@param callback fun(response: string|nil, err?: string): nil Callback that receives the API response or error
---@param headers? table<string, string> Optional request headers
---@param debug? boolean Enable verbose CLI output and stderr capture
---@param context? string Optional metrics label (e.g. "fetch_readme")
---@param uuid? string Optional unique identifier for request tracking
---@return nil
---@raises string if CLI spawning or pipe reading fails
function M.request(method, url, callback, headers, debug, context, uuid)
  local start_time = uv.hrtime()
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local safe_uuid = uuid or "n/a"
  local safe_context = context or "unspecified"
  local response_data = {}
  local stderr_data = {}

  local token = config.options.github_token
  local parsed = url:gsub("^https://api%.github%.com", "") -- relative API path
  local args = { "api", parsed, "--method", method }

  -- Add headers
  for k, v in pairs(headers or {}) do
    table.insert(args, "--header")
    table.insert(args, string.format("%s: %s", k, v))
  end

  -- Debug CLI output
  if debug then
    table.insert(args, "--verbose")
  end

  -- Optional: write CLI command to file
  pcall(function()
    local file = io.open("/tmp/gh-debug.txt", "a")
    if file then
      file:write("GH Request: gh " .. table.concat(args, " ") .. "\n")
      file:close()
    end
  end)

  -- Environment variable (token)
  local env = {}
  if token and token ~= "" then
    table.insert(env, "GITHUB_TOKEN=" .. token)
  end


  notify("[reposcope] GH Request: gh " .. table.concat(args, " "), vim.log.levels.TRACE)

  local handle = uv.spawn("gh", {
    args = args,
    stdio = { nil, stdout, stderr },
    env = env,
  }, function(code)
  ---@diagnostic disable-next-line: undefined-field
    stdout:close()
  ---@diagnostic disable-next-line: undefined-field
    stderr:close()

    local duration = (uv.hrtime() - start_time) / 1e6 -- ms

    if code ~= 0 then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "gh", safe_context, duration, code, "gh CLI error")
      end
      notify("[reposcope] gh exited with code " .. code, vim.log.levels.WARN)
      notify("[reposcope] stderr: " .. table.concat(stderr_data, ""), vim.log.levels.DEBUG)
      callback(nil, "gh request failed (code " .. code .. ")")
    else
      local result = table.concat(response_data)
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "gh", safe_context, duration, 200)
      end
      callback(result)
    end
  end)

  if not handle then
    callback(nil, "Failed to spawn gh CLI")
    return
  end

  ---@diagnostic disable-next-line: undefined-field
  stdout:read_start(function(err, data)
    if err then
      callback(nil, "gh stdout error: " .. err)
      return
    end
    if data then
      table.insert(response_data, data)
    end
  end)

  ---@diagnostic disable-next-line: undefined-field
  stderr:read_start(function(err, data)
    if err then
      notify("[reposcope] gh stderr read error: " .. err, vim.log.levels.ERROR)
      return
    end
    if data then
      table.insert(stderr_data, data)
      if debug then
        notify("[reposcope] gh stderr: " .. data, vim.log.levels.TRACE)
      end
    end
  end)
end

return M
