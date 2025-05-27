---@class CoreUtils
---@field tbl_find fun(tbl: table, value: any): integer|nil Searches for a value in the table and returns its index
---@field tbl_islist fun(t: any): boolean Checks if a table is a proper list: integer keys 1..#t without gaps or non-integer keys.
---@field flatten_table fun(input: table, result?: table): table Recursively flattens a nested table into a flat list
---@field dedupe_list fun(list: string[]): string[] Returns a new list with all duplicates removed (preserving order)
---@field put_to_front_if_present fun(list: string[], value: string): string[] Ensures that the given value appears first in the list if present
---@field ensure_string fun(val: string): string Ensures that a given argument 'val' is from type string, else returns empty string
---@field generate_uuid fun(): string  Creates a UUID based on actual timestamp
local M = {}

-- Low-Level Utilities (Libuv for High-Performance Timers)
local uv = vim.loop


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


---@brief Checks if a table is a proper list: integer keys 1..#t without gaps or non-integer keys.
---@param t any
---@return boolean
function M.tbl_islist(t)
  if type(t) ~= "table" then return false end

  local max = 0
  for k, _ in pairs(t) do
    if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
      return false
    end
    if k > max then max = k end
  end

  for i = 1, max do
    if t[i] == nil then return false end
  end

  return true
end


---Recursively flattens a nested table into a flat list.
---Traverses nested tables and collects all non-table values into a flat array-style table.
---@param input any The table (or value) to flatten
---@param result? table The table to accumulate into (optional, for recursion)
---@return table A flat array-style list of values
function M.flatten_table(input, result)
  result = result or {}

  if type(input) ~= "table" then
    table.insert(result, input)
    return result
  end

  for _, v in pairs(input) do
    if type(v) == "table" then
      M.flatten_table(v, result)
    else
      table.insert(result, v)
    end
  end

  return result
end


---@brief Returns a new list with all duplicates removed (preserving order)
---@param list string[]
---@return string[]
function M.dedupe_list(list)
  if type(list) ~= "table" then return {} end

  local seen = {}
  local result = {}

  for _, item in ipairs(list) do
    if not seen[item] then
      seen[item] = true
      table.insert(result, item)
    end
  end

  return result
end


---@brief Ensures that the given value appears first in the list if present.
---@param list string[] The input list (e.g. { "b", "a", "c", "a" })
---@param value string The value to move to the front (e.g. "a")
---@return string[] New list with `value` at position 1 (if present)
function M.put_to_front_if_present(list, value)
  if type(list) ~= "table" or type(value) ~= "string" then
    return {}
  end

  local result = {}
  for _, item in ipairs(list) do
    if item ~= value then
      table.insert(result, item)
    end
  end

  -- only insert if value was present at least once
  for _, item in ipairs(list) do
    if item == value then
      table.insert(result, 1, value)
      break
    end
  end

  return result
end


---Ensures that a given argument 'val' is from type string, else returns empty string
---@param val string
---@return string
function M.ensure_string(val)
  if type(val) == "string" then return val end
  if val == nil or val == vim.NIL then return "" end
  local ok, str = pcall(tostring, val)
  return ok and str or ""
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

    ---@diagnostic disable-next-line uv.now exists
    uv.now(),
    random(0, 0xffff),
    random(0, 0xffff),
    random(0, 0xffff),
    random(0, 0xffffffffffff)
  )
end

return M
