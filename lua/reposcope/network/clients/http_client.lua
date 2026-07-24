---@module 'reposcope.network.clients.http_client'
---@brief High-level HTTP client for Reposcope
---@description
--- Provides a unified interface for making HTTP requests using different tools.
--- Handles error cases, metrics, and request lifecycle management.

---@class HTTPClient : HTTPClientModule
local M = {}

-- Vim Utilities
local tbl_extend = vim.tbl_extend
-- Provider modules
local gh = require("reposcope.network.request_tools.gh")
local curl = require("reposcope.network.request_tools.curl")
local wget = require("reposcope.network.request_tools.wget")
-- Debug and Config dependencies
local get_option = require("reposcope.config").get_option
local new_error = require("reposcope.utils.error").new_error
local safe_call = require("reposcope.utils.error").safe_call


-- Per-provider config key holding that provider's API token
local TOKEN_OPTION = {
  github = "github_token",
  gitlab = "gitlab_token",
  codeberg = "codeberg_token",
}


---@private
---Builds the Authorization header based on the active provider, tool and token
---@param token string API token from config (for the active provider)
---@param tool string The selected request tool ("gh", "curl", "wget")
---@param provider string The active provider identifier ("github", "gitlab", "codeberg")
---@return table<string, string> Authorization headers (or empty)
local function _build_auth_header(token, tool, provider)
  if type(token) ~= "string" or token == "" then return {} end

  if tool == "gh" then
    return {} -- GH CLI handles auth internally
  elseif provider == "gitlab" then
    return { ["PRIVATE-TOKEN"] = token }
  elseif provider == "codeberg" then
    return { ["Authorization"] = "token " .. token }
  else
    return {
      ["Authorization"] = "Bearer " .. token
    }
  end
end


---Makes an HTTP request using the configured tool
---@param method string HTTP method
---@param url string Target URL
---@param callback fun(response: string|nil, error?: string|nil)
---@param headers? table<string, string>
---@param debug? boolean
---@param metrics_context? string
---@return nil
function M.request(method, url, callback, headers, debug, metrics_context)
  if type(url) ~= "string" or url == "" then
    callback(nil, nil) -- Silent error to clear preview window
    return
  end

  local uuid = require("reposcope.utils.core").generate_uuid()
  local request_module
  local default_tool = get_option("request_tool")
  local provider = get_option("provider")

  -- `gh` is the GitHub CLI and cannot talk to non-GitHub hosts; fall back to curl
  if default_tool == "gh" and provider ~= "github" then
    require("reposcope.utils.debug").notify(
      "[reposcope] 'gh' request tool only supports GitHub; falling back to 'curl' for provider '" .. tostring(provider) .. "'",
      3
    )
    default_tool = "curl"
  end

  local default_token = get_option(TOKEN_OPTION[provider] or "github_token")

  -- Select request tool
  if default_tool == "gh" then
    request_module = gh
  elseif default_tool == "curl" then
    request_module = curl
  elseif default_tool == "wget" then
    request_module = wget
  else
    local err = new_error("InvalidStateError", "Unsupported request tool: " .. tostring(default_tool))
    callback(nil, err.message)
    return
  end

  -- Build and merge headers
  local auth_headers = _build_auth_header(default_token, default_tool, provider)
  headers = tbl_extend("force", headers or {}, auth_headers)

  -- Make the request
  local result = safe_call(request_module.request, method, url, callback, headers, debug, metrics_context,
    uuid)

  if not result.ok then
    local err = new_error("NetworkError", "Request failed: " .. tostring(result.err))
    callback(nil, err.message)
  end
end

return M
