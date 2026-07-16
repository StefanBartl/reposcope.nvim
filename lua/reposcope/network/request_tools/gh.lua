---@module 'reposcope.network.request_tools.gh'
---@brief Executes GitHub CLI (`gh`) requests with metrics and async callback support.
---@description
--- Provides a wrapper around the GitHub CLI for issuing API requests.
--- Supports injecting headers, capturing metrics, error logging, and debug output.
--- It is designed to be used internally by GitHub-based fetch modules.
--- This is a low-level utility and does not format or interpret the response.

---@class GitHubRequest : GithubRequestModule
local M = {}

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

  -- Add headers
  for k, v in pairs(headers or {}) do
    args[#args + 1] = "--header"
    args[#args + 1] = k .. ": " .. v
  end

  -- Debug CLI output
  if debug then
    table.insert(args, "--verbose")
  end

  -- Optional: write CLI command to file
  pcall(function()
    local debug_path = vim.fn.stdpath("cache") .. "/reposcope/logs/gh-debug.txt"
    vim.fn.mkdir(vim.fn.fnamemodify(debug_path, ":h"), "p")
    local file = io.open(debug_path, "a")
    if file then
      file:write("GH Request: gh " .. table.concat(args, " ") .. "\n")
      file:close()
    end
  end)

  -- Environment variable (token). NOTE: libuv's spawn env option is an array
  -- of "KEY=VALUE" strings, not a dict — spawn_capture passes opts.env
  -- straight through without converting it.
  local env = {}
  if token and token ~= "" then
    table.insert(env, "GITHUB_TOKEN=" .. token)
  end

  notify("[reposcope] GH Request: gh " .. table.concat(args, " "), 2)

  local argv = { "gh" }
  for _, a in ipairs(args) do argv[#argv + 1] = a end

  spawn_capture(argv, { env = env }, function(result)
    local duration = (hrtime() - start_time) / 1e6 -- ms

    if not result.ok then
      if metrics.record_metrics() then
        metrics.increase_failed(safe_uuid, url, "gh", safe_context, duration, result.code, "gh CLI error")
      end
      notify("[reposcope] gh exited with code " .. result.code, 4)
      notify("[reposcope] stderr: " .. result.stderr, 2)
      callback(nil, "gh request failed (code " .. result.code .. ")")
    else
      if debug and result.stderr ~= "" then
        notify("[reposcope] gh stderr: " .. result.stderr, 4)
      end
      if metrics.record_metrics() then
        metrics.increase_success(safe_uuid, url, "gh", safe_context, duration, 200)
      end
      callback(result.stdout)
    end
  end)
end

return M
