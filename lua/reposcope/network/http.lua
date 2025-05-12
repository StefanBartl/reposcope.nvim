---@class HTTPModule
---@field get fun(url: string, callback: fun(response: string|nil, error_msg?: string|nil), debug?: boolean): nil Executes an HTTP GET request using curl
---@field urlencode fun(str: string): string Encodes a string for safe URL usage
local M = {}

local uv = vim.loop
local notify = require("reposcope.utils.debug").notify

--- HTTP GET Request with secure callback handling
---@param url string The URL for the HTTP request
---@param callback fun(response: string|nil, error_msg?: string) Callback function with the response content (string) or nil on failure
---@param debug? boolean Optional debug flag for stderr output
function M.get(url, callback, debug)
  local stdout = uv.new_pipe(false)
  local stderr = uv.new_pipe(false)
  local response_data = {}
  local stderr_data = {}
  local stdout_done = false
  local stderr_done = false
  local callback_called = false

  ---Secure Callback Execution
  local function secure_callback(response, error_msg)
    if not callback_called then
      callback(response, error_msg)
      callback_called = true
    end
  end

  ---Checks if both stdout and stderr have finished processing.
  local function check_done()
    if stdout_done and stderr_done then
      if #response_data == 0 then
        secure_callback(nil, #stderr_data > 0 and table.concat(stderr_data) or "Request failed")
      else
        secure_callback(table.concat(response_data), #stderr_data > 0 and table.concat(stderr_data) or nil)
      end
    end
  end

  local handle = uv.spawn("curl", {
    args = { "-s", url },
    stdio = { nil, stdout, stderr }
  }, function(code)
    if code ~= 0 then
      vim.schedule(function()
        notify("[reposcope] Curl process failed with code: " .. code, 4)
      end)
    end
    stdout_done = true
    stderr_done = true
    check_done()
  end)

  if not handle then
    vim.schedule(function()
      notify("[reposcope] Failed to start curl process", 4)
    end)
    secure_callback(nil, "Failed to start curl process")
    return
  end

  ---Reads the standard output (response content)
  stdout:read_start(function(err, data)
    if err then
      vim.schedule(function()
        notify("[reposcope] Error reading curl stdout: " .. err, 4)
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
        notify("[reposcope] Error reading curl stderr: " .. err, 4)
      end)
    elseif data and debug then
      vim.schedule(function()
        notify("[reposcope] curl stderr data: " .. data, 1)
      end)
      table.insert(stderr_data, data)
    elseif not data then
      stderr_done = true
      check_done()
    end
  end)
end


function M.urlencode(str)
  -- Replace newline characters with CRLF for URL encoding
  local crlf_encoded = str:gsub("\n", "\r\n")

  -- Convert all other special characters to percent-encoded form
  local url_encoded = crlf_encoded:gsub("([^%w%-_.~])", function(char)
    return string.format("%%%02X", string.byte(char))
  end)

  return url_encoded
end

return M
