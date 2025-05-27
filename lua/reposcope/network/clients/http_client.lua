---@class HTTPClient
local M = {}

-- Debug and Config modules
local notify = require("reposcope.utils.debug").notify
local get_option = require("reposcope.config").get_option

local default_tool = get_option("request_tool")
print("request_tool: ", default_tool)
local default_token = get_option("github_token")
print("gh token: ", default_token)


---@private
local function build_auth_header(token, tool)
  if type(token) ~= "string" or token == "" then return {} end
  if tool == "curl" or tool == "wget" then
    return { ["Authorization"] = "Bearer " .. token }
  elseif tool == "gh" then
    return {} -- gh uses env
  end
  return {}
end

--- Central request dispatcher
---@param method string
---@param url string
---@param callback fun(response: string|nil, error_msg?: string|nil)
---@param headers? table
---@param debug? boolean
---@param metrics_context? string
function M.request(method, url, callback, headers, debug, metrics_context)
  local uuid = require("reposcope.utils.core").generate_uuid()
  local request_module

  if default_tool == "gh" then
    request_module = require("reposcope.network.request_tools.gh")
  elseif default_tool == "curl" then
    request_module = require("reposcope.network.request_tools.curl")
  elseif default_tool == "wget" then
    request_module = require("reposcope.network.request_tools.wget")
  else
    notify("[reposcope] Unknown request default_tool: " .. tostring(default_tool), 4)
    callback(nil, "Unsupported request default_tool")
    return
  end

  local auth_headers = build_auth_header(default_token, default_tool)
  headers = vim.tbl_extend("force", headers or {}, auth_headers)

  request_module.request(method, url, callback, headers, debug, metrics_context, uuid)
end

return M

