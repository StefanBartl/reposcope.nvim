---@class UtilsProtection Utility functions related to value normalization and scratch buffer management.
---@field count_or_default fun(val: table|number|string, default: number): number Returns the item count if `val` is a table, the number if `val` is a number, or `default` otherwise.
---@field create_named_buffer fun(name: string): integer Creates a named scratch buffer, replacing any existing one with the same name.
---@field is_valid_path fun(path: string, nec_filename: boolean): boolean Validates if a given path or optional filepath is a valid and writable file path
---@field safe_mkdir fun(path: string): boolean Safely creates a directory (including parent directories)
local M = {}

local notify = require("reposcope.utils.debug").notify
local debugf = require("reposcope.utils.debug").debugf

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
--- @desc: creates not existing directory if path is valid
---@param path string The full path to the log file
---@param nec_filename? boolean Optional parameter to toggle testing filename
function M.is_valid_path(path, nec_filename)
  path = vim.fn.expand(path)

  local filename = nil
  if nec_filename == true then
    filename = vim.fn.fnamemodify(path, ":t")
    print("filename:", filename)
  elseif not path:match("/$") then  --INFO: This is needed for user safety. `fnamemodify()` doesnt recognizy directories without ending '/'
    path = path .. "/"
  end

  -- Extract directory and filename --REF: outsource
  local dir = vim.fn.fnamemodify(path, ":h")
  print("dir:", dir)

  local dir_created = M.safe_mkdir(dir)
  local dir_ok = M.is_dir_writeable(dir)

  if dir_created == false or dir_ok == false then
    print("[reposcope] Error with creation of (writeable) directory:", dir)
    return false
  end

  if dir_ok and nec_filename == false then
    print("Directory is valid path:", dir)
    return true
  end

  ---DEBUG: filename should be tested out
  -- Check if the filename is not empty
  if dir_ok and nec_filename == true and filename == "" then
      print("Path is valid bur filename is missing", dir, filename)
      return false
  else
    print("[reposcope] Path with filename ok:", dir, filename)
    return true
  end

end

---Safely creates a directory (including parent directories)
---@param path string The directory path to create
function M.safe_mkdir(path)
  if vim.fn.isdirectory(path) == 1 then
    print("directory exists")
    return true
  end

  local created = vim.fn.mkdir(path, "p")
  if created == 0 then
    vim.notify("[reposcope] Error: Directory could not be created: " .. path, 4)
    return false
  end

  if vim.fn.isdirectory(path) == 1 then
    print("directory succesfully created")
    return true
  else
    vim.notify("[reposcope] Error: Directory was not created, but mkdir did not return an error: " .. path, 4)
    return false
  end
end

-- Check if the directory is writable
function M.is_dir_writeable(dir)
 local testfile = vim.fn.fnameescape(dir .. "/.rs_write_test")
 local file, err = io.open(testfile, "w")
 if file then
   file:close()
   os.remove(testfile)
   print("Directory writeable")
   return true
 else
   notify(
     string.format("[reposcope] Error: Directory is not writable (%s). Reason: %s", dir, err),
     4
   )
   return false
 end
end

return M
