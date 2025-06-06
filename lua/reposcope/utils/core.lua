---@module 'reposcope.utils.core'
---@brief Core utility functions for list operations, UUIDs, and type safety.
---@description
--- This module provides reusable low-level utilities including table operations,
--- value validation, and UUID generation. It is used across multiple layers of
--- Reposcope to simplify logic and reduce redundancy.

---@class CoreUtils : CoreUtilsModule
local M = {}

-- System Access
local uv = vim.loop


---Returns the index of a value in a list-style table
---@param tbl any[] The table to search in
---@param value any The value to search for
---@return integer|nil
function M.tbl_find(tbl, value)
  for i = 1, #tbl do
    if tbl[i] == value then return i end
  end
  return nil
end

---Checks if the given table is a proper list (1..n, no gaps)
---@param t any
---@return boolean
function M.tbl_islist(t)
  if type(t) ~= "table" then return false end

  local max = 0
  for k in pairs(t) do
    if type(k) ~= "number" or k < 1 or k ~= math.floor(k) then
      return false
    end
    if k > max then max = k end
  end

  for i = 1, max do
    if t[i] == nil then return false end
  end

  return true
end

---Flattens a nested table into a flat list of values
---@param input any
---@param result? any[]
---@return any[]
function M.flatten_table(input, result)
  result = result or {}
  if type(input) ~= "table" then
    result[#result + 1] = input
    return result
  end

  for _, v in pairs(input) do
    if type(v) == "table" then
      M.flatten_table(v, result)
    else
      result[#result + 1] = v
    end
  end

  return result
end

---Removes duplicate strings from a list while preserving order
---@param list string[]
---@return string[]
function M.dedupe_list(list)
  if type(list) ~= "table" then return {} end
  local seen, result = {}, {}
  for i = 1, #list do
    local item = list[i]
    if not seen[item] then
      seen[item] = true
      result[#result + 1] = item
    end
  end
  return result
end

---Moves a value to the front of the list, if present
---@param list string[]
---@param value string
---@return string[]
function M.put_to_front_if_present(list, value)
  if type(list) ~= "table" or type(value) ~= "string" then return {} end

  local found = false
  local result = {}

  for i = 1, #list do
    local item = list[i]
    if item == value then
      found = true
    else
      result[#result + 1] = item
    end
  end

  if found then
    table.insert(result, 1, value)
  end

  return result
end

---Ensures the given value is returned as a string, or fallback ""
---@param val any
---@return string
function M.ensure_string(val)
  if type(val) == "string" then return val end
  if val == nil or val == vim.NIL then return "" end
  local ok, str = pcall(tostring, val)
  return ok and str or ""
end

---Generates a UUID based on current timestamp and random components
---@return UUID
function M.generate_uuid()
  local random = math.random
  return string.format(
    "%08x-%04x-%04x-%04x-%012x",
    uv.now(), -- high-resolution base
    random(0, 0xffff),
    random(0, 0xffff),
    random(0, 0xffff),
    random(0, 0xffffffffffff)
  )
end

return M
