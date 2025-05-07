---@class HTTPModule
---@field get fun(url: string, callback: fun(response: string|nil), debug?: boolean): nil Executes an HTTP GET request using curl
local M = {}

local uv = vim.loop
local notify = require("reposcope.utils.debug").notify

---Performs an HTTP GET request and returns the response.
---@param url string The URL for the HTTP request
---@param callback fun(response: string|nil) Callback function with the response content (string) or nil on failure
---@param debug? boolean Optional debug flag for stderr output
function M.get(url, callback, debug)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local response_data = {}
  local stderr_data = {}
  local stdout_done = false
  local stderr_done = false

  ---Checks if both stdout and stderr have finished processing.
  local function check_done()
    if stdout_done and stderr_done then
      if #response_data == 0 then
        callback(nil)
      else
        callback(table.concat(response_data))
      end
    end
  end

  local handle = uv.spawn("curl", {
    args = { "-s", url },
    stdio = { nil, stdout, stderr }
  }, function(code)
    if code ~= 0 then
      vim.schedule(function()
        notify("[reposcope] Curl process failed with code: " .. code, vim.log.levels.ERROR)
      end)
    end
    stdout_done = true
    stderr_done = true
    check_done()
  end)

  if not handle then
    vim.schedule(function()
      notify("[reposcope] Failed to start curl process", vim.log.levels.ERROR)
    end)
    callback(nil)
    return
  end

  ---Reads the standard output (response content)
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        notify("[reposcope] Error reading curl stdout: " .. err, vim.log.levels.ERROR)
      end)
      stdout_done = true
      check_done()
      return
    end

    if data then
      table.insert(response_data, data)
    else
      stdout_done = true
      check_done()
    end
  end)

  ---Reads the standard error (debugging information)
  stderr:read_start(function(err, data)
    if err then
      vim.schedule(function()
        notify("[reposcope] Error reading curl stderr: " .. err, vim.log.levels.ERROR)
      end)
    elseif data and debug then
      vim.schedule(function()
        notify("[reposcope] curl stderr data: " .. data, vim.log.levels.DEBUG)
      end)
      table.insert(stderr_data, data)
    elseif not data then
      stderr_done = true
      check_done()
    end
  end)
end

return M
