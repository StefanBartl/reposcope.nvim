---@module 'reposcope.network.api_client'
---@brief High-level HTTP API request handler for Reposcope
---@description
--- Provides a high-level wrapper around HTTP requests for Reposcope.
--- Prevents duplicate requests by UUID, injects headers, and delegates execution.

---@class API : APIModule
local M = {}

-- HTTP Client
local http_client_request = require("reposcope.network.clients.http_client").request
-- Request UUID State
local request_is_registered = require("reposcope.state.requests_state").is_registered
local request_is_active = require("reposcope.state.requests_state").is_request_active
local request_start = require("reposcope.state.requests_state").start_request
local request_end = require("reposcope.state.requests_state").end_request
-- Debug
local notify = require("reposcope.utils.debug").notify


---Sends a generalized API request (GET, POST, etc.)
---@param method string
---@param url string
---@param callback fun(response: string|nil, error?: string|nil)
---@param headers? table
---@param context? string
---@param uuid string
---@return nil
function M.request(method, url, callback, headers, context, uuid)
  context = context or "general"

  headers = vim.tbl_extend("force", { ["Accept"] = "application/vnd.github+json" }, type(headers) == "table" and headers or {})

  http_client_request(method, url, function(response, error)

    if error then
      callback(nil, error)
      return
    end

    callback(response, nil)
  end, headers)
end

return M

