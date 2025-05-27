local uv = vim.loop
local notify = require("reposcope.utils.debug").notify
local metrics = require("reposcope.utils.metrics")

local M = {}

function M.request(method, url, callback, headers, debug, context, uuid)
  local start_time = uv.hrtime()
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local response_data = {}

  local args = { "-s", "-X", method, url }
  for k, v in pairs(headers or {}) do
    table.insert(args, "-H")
    table.insert(args, k .. ": " .. v)
  end

  notify(string.format("[reposcope] CURL Request: curl %s", table.concat(args, " ")), 2)


  local handle = uv.spawn("curl", {
    args = args,
    stdio = { nil, stdout, stderr },
  }, function(code)
    stdout:close()
    stderr:close()
    local duration = (uv.hrtime() - start_time) / 1e6
    if code ~= 0 then
      if context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "curl", context, duration, code, "curl error")
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

  stdout:read_start(function(err, data)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6

    if err then
      if context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "curl", context, duration_ms, 0, "Error reading curl stdout: " .. err)
      end
      callback(nil, "curl stdout error: " .. err)
      return
    end

    if data then
      table.insert(response_data, data)
    else
      local response = table.concat(response_data)

      if context and metrics.record_metrics() then
        metrics.increase_success(uuid, url, "curl", context, duration_ms, 200)
      end

      callback(response)
    end
  end)

  stderr:read_start(function(err, data)
    local duration_ms = (vim.loop.hrtime() - start_time) / 1e6

    if err then
      if context and metrics.record_metrics() then
        metrics.increase_failed(uuid, url, "curl", context, duration_ms, 0, "Error reading curl stderr: " .. err)
      end
      notify(string.format("[reposcope] curl stderr read error: %s", err), 3)
      return
    end

    if debug and data then
      notify(string.format("[reposcope] curl stderr: %s", data), 2)
    end
  end)
end

return M
