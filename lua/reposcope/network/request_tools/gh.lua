-- NOTE: Annotations
local uv = vim.uv or vim.loop
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")
local config = require("reposcope.config")

local M = {}

---Issues a GitHub CLI API request and returns the response to callback
---@param method string HTTP method (e.g. "GET", "POST")
---@param url string Full GitHub API URL (will be parsed)
---@param callback fun(response: string|nil, err?: string): nil Callback with response or error
---@param headers? table<string, string> Optional headers
---@param debug? boolean Enable debug output
---@param context? string Metrics context label
---@param uuid? string Unique identifier for metrics logging
---@return nil
function M.request(method, url, callback, headers, debug, context, uuid)
  local start_time = uv.hrtime()
  local token = config.options.github_token

  local parsed = url:gsub("^https://api%.github%.com", "") -- relative API path
  local args = { "api", parsed, "--method", method }

  -- Add headers
  for k, v in pairs(headers or {}) do
    table.insert(args, "--header")
    table.insert(args, string.format("%s: %s", k, v))
  end

  -- Optional: verbose flag for debugging
  if debug then
    table.insert(args, "--verbose")
  end

  -- Debug log to disk
  pcall(function()
    local file = io.open("/tmp/gh-debug.txt", "a")
    if file then
      file:write("GH Request: gh " .. table.concat(args, " ") .. "\n")
      file:close()
    end
  end)

  local env = {}
  if token and token ~= "" then
    table.insert(env, "GITHUB_TOKEN=" .. token)
  end

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local response_data = {}
  local stderr_data = {}

  notify("[reposcope] GH Request: gh " .. table.concat(args, " "), 2)

  local handle = uv.spawn("gh", {
    args = args,
    stdio = { nil, stdout, stderr },
    env = env,
  }, function(code)
     ---@diagnostic disable-next-line: undefined-field
    stdout:close()
     ---@diagnostic disable-next-line: undefined-field
    stderr:close()

    local duration = (uv.hrtime() - start_time) / 1e6
    local safe_uuid = uuid or "n/a"
    local safe_context = context or "unspecified"

    if code ~= 0 then
      if context and metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "gh", safe_context, duration, code, "gh CLI error")
      end
      notify("[reposcope] gh exited with code " .. code, 3)
      notify("[reposcope] stderr: " .. table.concat(stderr_data, ""), 3)
      callback(nil, "gh request failed (code " .. code .. ")")
    else
      local result = table.concat(response_data)
      if context and metrics.record_metrics() then
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
      notify("[reposcope] gh stderr read error: " .. err, 3)
      return
    end
    if data then
      table.insert(stderr_data, data)
      if debug then
        notify("[reposcope] gh stderr: " .. data, 2)
      end
    end
  end)
end

return M

