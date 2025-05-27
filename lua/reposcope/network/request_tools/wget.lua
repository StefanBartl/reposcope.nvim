local M = {}

---@diagnostic disable
function M.request(method, url, callback, headers, debug, context, uuid)
  callback(nil, "wget not implemented")
end

return M
