---@module 'reposcope.utils.protection'
---@brief Filesystem safety, validation, and path protection utilities.

---@class UtilsProtection : UtilsProtectionModule
local M = {}

-- Vim Utilities
local defer_fn = vim.defer_fn
local fnameescape = vim.fn.fnameescape
local fnamemodify = vim.fn.fnamemodify
local isdirectory = vim.fn.isdirectory
local mkdir = vim.fn.mkdir
local system = vim.fn.system
local expand = vim.fn.expand
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_buf_delete = vim.api.nvim_buf_delete
local nvim_create_buf = vim.api.nvim_create_buf
local nvim_buf_set_name = vim.api.nvim_buf_set_name
-- Debugging Utility (Enhanced Debugging with Formatted Output)
local debug = require("reposcope.utils.debug")
local debugf = debug.debugf
local notify = debug.notify
local safe_call = require("reposcope.utils.error").safe_call
-- State
local ui_state = require("reposcope.state.ui.ui_state")


---@param fn fun()
---@param delay_ms integer
---@return fun()
function M.debounce(fn, delay_ms)
  local timer = nil
  local args = {}

  ---@diagnostic disable-next-line: redundant-parameter
  return function(...)
    args = { ... }

    if timer then
      timer:stop()
      timer:close()
    end

    timer = defer_fn(function()
      ---@diagnostic disable-next-line: redundant-parameter
      fn(unpack(args))
      timer = nil
    end, delay_ms)
  end
end

---@param fn fun()
---@param delay_ms integer
---@return fun(), fun(): integer
function M.debounce_with_counter(fn, delay_ms)
  local timer = nil
  local skipped = 0
  local args = {}

  local function call(...)
    args = { ... }

    if timer then
      timer:stop()
      timer:close()
      skipped = skipped + 1
    end

    timer = defer_fn(function()
      ---@diagnostic disable-next-line: redundant-parameter
      fn(unpack(args))
      timer = nil
    end, delay_ms)
  end

  local function get_skipped()
    return skipped
  end

  return call, get_skipped
end

---Normalizes a value into a non-zero count.
--- - If `val` is a table, returns its element count (default if empty).
--- - If `val` is a number, returns it (or default if zero).
--- - Otherwise, returns the default.
---@param val table|number|string Input value (e.g. a table, number, or empty string)
---@param default number Fallback value if input is empty, zero, or invalid
---@return number
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
---@return integer|nil Created buffer handle or nil if creation failed
function M.create_named_buffer(name)
  local map = {
    ["reposcope://background"] = "back",
    ["reposcope://preview"] = "preview",
    ["reposcope://list"] = "list",
    ["reposcope://prompt"] = "prompt",
    ["reposcope://prompt_prefix"] = "prompt_prefix",
    ["reposcope://readme_viewer"] = "readme_viewer",
  }

  local buf_key = map[name]
  local existing_buf = buf_key and ui_state.buffers[buf_key] or nil

  if existing_buf and nvim_buf_is_valid(existing_buf) then
    local ok_del, err = pcall(nvim_buf_delete, existing_buf, { force = true })
    if not ok_del then
      notify("[reposcope] Failed to delete buffer '" .. name .. "': " .. tostring(err), 4)
    end
    ui_state.buffers[buf_key] = nil
  end

  local ok_new, buf = pcall(nvim_create_buf, false, true)
  if not ok_new or not buf then
    notify("[reposcope] Failed to create buffer '" .. name .. "'", 5)
    return nil
  end

  local ok_setname, err = pcall(nvim_buf_set_name, buf, name)
  if not ok_setname then
    notify("[reposcope] Failed to name buffer '" .. name .. "': " .. tostring(err), 4)
  end

  if buf_key then
    ui_state.buffers[buf_key] = buf
  end

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

---Validates if a given file path is a valid and writable log file path
--- Sideffect: if path is valid and directory does not exost, it creates it
---@param path string The full path to the log file
---@param nec_filename? boolean Optional parameter to toggle testing filename
---@return boolean
function M.is_valid_path(path, nec_filename)
  path = expand(path)

  local filename = nil
  if nec_filename == true then
    filename = fnamemodify(path, ":t")
  elseif not path:match("/$") then -- This check is needed for user safety. `fnamemodify()` doesnt recognizy directories without ending '/'
    path = path .. "/"
  end

  -- Extract directory and filename
  local dir = fnamemodify(path, ":h")
  local dir_ok = M.safe_mkdir(dir)

  if dir_ok == false then
    debugf("[reposcope] Error with creation of (writeable) directory: " .. dir, 3)
    return false
  end

  if dir_ok and nec_filename == false then
    return true
  end

  -- Check if the filename is not empty
  local ok, err = M.is_valid_filename(filename)
  if not ok then
    debugf("Path is valid but filename invalid: " .. dir .. "/" .. filename .. " (" .. err .. ")", 3)
    return false
  else
    return true
  end
end

---Safely creates a directory (including parent directories)
---@param path string The directory path to create
---@return boolean
function M.safe_mkdir(path)
  if isdirectory(path) == 1 then
    return true
  end

  local created = mkdir(path, "p")
  if created == 0 then
    notify("[reposcope] Error: Directory could not be created: " .. path, 4)
    return false
  end

  if isdirectory(path) == 1 then
    if M.is_dir_writeable(path) then
      return true
    else
      debugf("directory created, but not writeable", 3)
      return false
    end
  else
    notify("[reposcope] Error: Directory was not created, but mkdir did not return an error: " .. path, 4)
    return false
  end
end

-- Check if the directory is writable
---@return boolean
function M.is_dir_writeable(dir)
  local testfile = fnameescape(dir .. "/.rs_write_test")
  local file, err = io.open(testfile, "w")
  if file then
    file:close()
    os.remove(testfile)
    return true
  else
    notify("[reposcope] Error: Directory " .. dir .. " is not writable. Reason: " .. err, 4)
    return false
  end
end

---Executes a shell command safely and returns the success status and output.
---@param command string The shell command to be executed
---@return boolean success True if the command succeeded (exit code 0)
---@return string output The standard output (or error output) of the command
function M.safe_execute_shell(command)
  local result = system(command)
  if vim.v.shell_error ~= 0 then
    return false, result
  end
  return true, result
end

return M
