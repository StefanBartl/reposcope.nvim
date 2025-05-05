
--- @class UtilsProtection Utility functions related to value normalization and scratch buffer management.
--- @field count_or_default fun(val: table|number|string, default: number): number Returns the item count if `val` is a table, the number if `val` is a number, or `default` otherwise.
--- @field create_named_buffer fun(name: string): integer Creates a named scratch buffer, replacing any existing one with the same name.
local M = {}

--- Normalizes a value into a non-zero count.
--- - If `val` is a table, returns its element count (default if empty).
--- - If `val` is a number, returns it (or default if zero).
--- - Otherwise, returns the default.
---
--- @param val table|number|string Input value (e.g. a table, number, or empty string)
--- @param default number Fallback value if input is empty, zero, or invalid
--- @return number Normalized result
function M.count_or_default(val, default)
  if type(val) == "table" then
    local n = vim.tbl_count(val)
    return (n == 0) and default or n
  elseif type(val) == "number" then
    return (val == 0) and default or val
  else
    return default
  end
end

--- Creates a scratch buffer with a given name.
--- If a buffer with that name exists, it is deleted and replaced.
---
--- @param name string Buffer name (e.g. "reposcope://preview")
--- @return integer buf Handle to the newly created buffer
function M.create_named_buffer(name)
  local existing = vim.fn.bufnr(name)
  if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
    vim.api.nvim_buf_delete(existing, { force = true })
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  return buf
end


return M
