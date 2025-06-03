---@module 'reposcope.state.requests_state'
---@brief Manages the lifecycle state of asynchronous requests using UUIDs
---@description
--- This module tracks ongoing requests using UUIDs. It supports registering new
--- requests with an initial inactive state, marking them active, ending them,
--- and checking if they are registered or currently active.

---@class RequestStateManager : RequestStateManagerModule
local M = {}


---@type table<string, boolean>
M.requests = {}

---Registers a new UUID in an inactive state
---@param uuid string
function M.register_request(uuid)
  if uuid and type(uuid) == "string" and uuid ~= "" then
    M.requests[uuid] = false
  end
end


---Marks a registered UUID as active
---@param uuid string
function M.start_request(uuid)
  if M.requests[uuid] == false then
    M.requests[uuid] = true
  end
end


---Marks a UUID request as completed
---@param uuid string
function M.end_request(uuid)
  M.requests[uuid] = nil
end


---Checks if a UUID was registered
---@param uuid string
---@return boolean
function M.is_registered(uuid)
  return M.requests[uuid] ~= nil
end


---Checks if a UUID is currently marked active
---@param uuid string
---@return boolean
function M.is_request_active(uuid)
  return M.requests[uuid] == true
end


---Clears all tracked UUID requests
function M.clear_all_requests()
  M.requests = {}
end

return M
