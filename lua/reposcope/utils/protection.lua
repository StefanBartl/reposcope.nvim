---@class UtilsProtection Utility functions related to value normalization and scratch buffer management
---@field count_or_default fun(val: table|number|string, default: number): number Returns the item count if `val` is a table, the number if `val` is a number, or `default` otherwise
---@field create_named_buffer fun(name: string): integer Creates a named scratch buffer, replacing any existing one with the same name
---@field is_valid_filename fun(filename: string|nil): boolean, string Normalizes a value into a non-zero count
---@field is_valid_path fun(path: string, nec_filename: boolean): boolean Validates if a given path or optional filepath is a valid and writable file path
---@field safe_mkdir fun(path: string): boolean Safely creates a directory (including parent directories)
---@field safe_execute_shell fun(command: string): boolean, string Executes a shell command safely and returns the success status and output
local M = {}

local debug = require("reposcope.utils.debug")

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

--- Checks if the given filename is valid according to standard file naming rules.
--- A valid filename:
--- - is not nil
--- - is not empty
--- - does not contain invalid characters: /, \, ?, *, :, |, ", <, >, and \0 (Nullbyte)
--- - Does not consist of only whitespace
--- @param filename string|nil The filename to validate
--- @return boolean, string Returns true if the filename is valid, false otherwise. 
function M.is_valid_filename(filename)
  if filename == nil then
    return false, "Filename is nil."
  end

  local invalid_chars = '[\\/:*?"<>|%z]'

  if filename == "" then
    return false, "Filename is missing."
  end

  if filename:match("^%s*$") then
    return false, "Filename is only whitespace."
  end

  if filename:match(invalid_chars) then
    return false, "Filename contains invalid characters."
  end

  return true, ""
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
  elseif not path:match("/$") then  -- This check is needed for user safety. `fnamemodify()` doesnt recognizy directories without ending '/'
    path = path .. "/"
  end

  -- Extract directory and filename
  local dir = vim.fn.fnamemodify(path, ":h")
  local dir_ok = M.safe_mkdir(dir)

  if dir_ok == false then
    debug.debugf("[reposcope] Error with creation of (writeable) directory: " .. dir, 3)
    return false
  end

  if dir_ok and nec_filename == false then
    return true
  end

  -- Check if the filename is not empty
  local ok, err = M.is_valid_filename(filename)
  if not ok then
    debug.debugf("Path is valid but filename invalid: " .. dir .. "/" .. filename .. " (" .. err .. ")", 3)
    return false
  else
    return true
  end

end

---Safely creates a directory (including parent directories)
---@param path string The directory path to create
function M.safe_mkdir(path)
  if vim.fn.isdirectory(path) == 1 then
    return true
  end

  local created = vim.fn.mkdir(path, "p")
  if created == 0 then
    debug.notify("[reposcope] Error: Directory could not be created: " .. path, 4)
    return false
  end

  if vim.fn.isdirectory(path) == 1 then
    if M.is_dir_writeable(path) then
      return true
    else
      debug.debugf("directory created, but not writeable", 3)
      return false
    end
  else
    debug.notify("[reposcope] Error: Directory was not created, but mkdir did not return an error: " .. path, 4)
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
   return true
 else
   debgug.notify(
     string.format("[reposcope] Error: Directory is not writable (%s). Reason: %s", dir, err),
     4
   )
   return false
 end
end

---Executes a shell command safely and returns the success status and output
---@param command string The shell command to be executed
function M.safe_execute_shell(command)
  local result = vim.fn.system(command)
  if vim.v.shell_error ~= 0 then
    return false, result
  end
  return true, result
end

return M
