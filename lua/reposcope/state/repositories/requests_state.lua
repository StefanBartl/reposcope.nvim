---@class RequestStateManager
---@field repositories table<string, boolean> Tracks active requests for repositories by UUID
--NOTE: implement this new functions
---@field start_request fun(uuid: string): nil Marks as request as active for a specific UUID
---@field end_request fun(uuid: string): nil Markds a request as completed for a specific UUID
---@field is_request_active fun(uuid: string): boolean Checks if a request is currentrly active, false otherwise
---@field clear_all_requests fun(): nil Clears all active requests (reset the state)
local M = {}

M.repositories= { }

--- Marks a request as active for a specific UUID
---@param uuid string The unique identifier for the request
function M.start_request(uuid)
  M.repositories[uuid] = true
end

--- Marks a request as completed for a specific UUID
---@param uuid string The unique identifier for the request
function M.end_request(uuid)
  M.repositories[uuid] = nil
end

--- Checks if a request is currently active for a specific UUID
---@param uuid string The unique identifier for the request
---@return boolean Returns true if the request is active, false otherwise
function M.is_request_active(uuid)
  return M.repositories[uuid] == true
end

--- Clears all active requests (resets the state)
function M.clear_all_requests()
  M.repositories = {}
end

return M
