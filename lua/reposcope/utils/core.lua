---@class CoreUtils
---@field tbl_find fun(tbl: table, value: any): integer|nil Searches for a value in the table and returns its index
---@field generate_uuid fun(): string  Creates a UUID based on actual timestamp
local M = {}

local uv = vim.loop -- Neovim's built-in libuv module for high-performance timers

---Searches for a value in the table and returns its index.
---@param tbl table The table to search in.
---@param value any The value to search for.
---@return integer|nil The index of the value if found, nil otherwise.
---@brief Finds the index of a value in a given table.
---@description
--- This function searches for a specific value in the provided table using
--- a linear search. It is optimized for tables indexed with integers (arrays).
--- If the value is found, it returns its index. If not, it returns nil
function M.tbl_find(tbl, value)
  for index, v in ipairs(tbl) do
    if v == value then
      return index
    end
  end
  return nil
end

--- Creates a UUID based on actual timestamp.
---@return string Unique UUID string.
---@brief Generates a UUID (Universally Unique Identifier) based on the current timestamp
---@description
---This function generates a UUID using a combination of the current timestamp 
---(using `uv.now()` for high-resolution time) and random values. It avoids
---system calls and provides a fast, cross-platform UUID generation method
---
--- The format of the UUID is: XXXXXXXX-XXXX-XXXX-XXXX-XXXXXXXXXXXX
function M.generate_uuid()
  local random = math.random
  return string.format(
    "%08x-%04x-%04x-%04x-%012x",
    uv.now(),
    random(0, 0xffff),
    random(0, 0xffff),
    random(0, 0xffff),
    random(0, 0xffffffffffff)
  )
end

return M
