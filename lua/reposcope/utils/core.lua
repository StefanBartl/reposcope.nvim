---@class CoreUtils
---@field tbl_find fun(tbl: table, value: any): any|nil Adds a find in table function to the table module
local M = {}

---Adds a find in table function to the table module
---@param tbl table The table to search in for 
---@param value any The value to search for
function M.tbl_find(tbl, value)
  for index, v in ipairs(tbl) do
    if v == value then
      return index
    end
  end
  return nil
end

return M
