local uv = vim.loop
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")
local config = require("reposcope.config")

local M = {}

function M.request(method, url, callback, _, debug, context, uuid)
  local start_time = uv.hrtime()
  local token = config.options.github_token

  local args = { "api", "-X", method, url }
  local env = {}
  if token and token ~= "" then
    table.insert(env, "GITHUB_TOKEN=" .. token)
  end

  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local response_data = {}

  local handle = uv.spawn("gh", {
    args = args,
    stdio = { nil, stdout, stderr },
    env = env,
  }, function(code)
    stdout:close()
    stderr:close()
    local duration = (uv.hrtime() - start_time) / 1e6
    if code ~= 0 then
      if context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "gh", context, duration, code, "gh error")
      end
      callback(nil, "gh request failed (code " .. code .. ")")
    else
      callback(table.concat(response_data))
    end
  end)

  if not handle then
    callback(nil, "Failed to spawn gh")
    return
  end

  stdout:read_start(function(err, data)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6

    if err then
      if context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "gh", context, duration_ms, 0, "Error reading gh stdout: " .. err)
      end
      callback(nil, "gh stdout error: " .. err)
      return
    end

    if data then
      table.insert(response_data, data)
    else
      local response = table.concat(response_data)

      if context and metrics.record_metrics() then
        metrics.increase_success(uuid, url, "gh", context, duration_ms, 200)
      end

      callback(response)
    end
  end)

  stderr:read_start(function(err, data)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6

    if err then
      if context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "gh", context, duration_ms, 0, "Error reading gh stderr: " .. err)
      end
      notify(string.format("[reposcope] gh stderr read error: %s", err), 3)
      return
    end

    if debug and data then
      notify(string.format("[reposcope] gh stderr: %s", data), 2)
    end
  end)
end

return M
