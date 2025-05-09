---@class UtilsProtection Utility functions related to value normalization and scratch buffer management.
---@field count_or_default fun(val: table|number|string, default: number): number Returns the item count if `val` is a table, the number if `val` is a number, or `default` otherwise.
---@field create_named_buffer fun(name: string): integer Creates a named scratch buffer, replacing any existing one with the same name.
---@field is_valid_path fun(filepath: string): boolean Validates if a given file path is a valid and writable log file path
local M = {}

local notify = require("reposcope.utils.debug").notify

---Normalizes a value into a non-zero count.
--- - If `val` is a table, returns its element count (default if empty).
--- - If `val` is a number, returns it (or default if zero).
--- - Otherwise, returns the default.
---@param val table|number|string Input value (e.g. a table, number, or empty string)
---@param default number Fallback value if input is empty, zero, or invalid
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

---Creates a scratch buffer with a given name.
---If a buffer with that name exists, it is deleted and replaced.
---@param name string Buffer name (e.g. "reposcope://preview")
function M.create_named_buffer(name)
  local existing = vim.fn.bufnr(name)
  if existing ~= -1 and vim.api.nvim_buf_is_valid(existing) then
    vim.api.nvim_buf_delete(existing, { force = true })
  end
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_name(buf, name)
  return buf
end

--- Validates if a given file path is a valid and writable log file path
---@param filepath string The full path to the log file
---@return boolean True if the path is valid, false otherwise
function M.is_valid_path(filepath)
  -- Check for invalid characters (cross-platform)
  local invalid_chars = '[<>:"/\\|?*]'
  if filepath:match(invalid_chars) then
    notify("[reposcope] The path contains invalid characters.", vim.log.levels.ERROR)
    return false
  end

  -- Extract directory and filename
  local dir = vim.fn.fnamemodify(filepath, ":h")
  local filename = vim.fn.fnamemodify(filepath, ":t")

  -- Ensure the directory exist
  if not vim.fn.isdirectory(dir) then
    local created = vim.fn.mkdir(dir, "p")
    if created == 0 then
      notify("[reposcope] The directory doesnt exist and could not be created.", vim.log.levels.ERROR)
      return false
    end
  end

  -- Check if the filename is not empty
  if filename == "" then
    notify("Filename is missing in the path.", vim.log.levels.ERROR)
    return false
  end

  -- Check if the directory is writable
  local testfile = dir .. "/.rs_write_test"
  local file = io.open(testfile, "w")
  if file then
    file:close()
    os.remove(testfile)
  else
    notify("Directory is not writable.")
    return false
  end

  return true
end

return M
