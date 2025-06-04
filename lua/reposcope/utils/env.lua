---@module 'reposcope.utils.env'
---@brief Utility functions to access environment variables safely
---@description
--- This module provides robust utilities to check and retrieve environment variables.
--- It supports standard access via `vim.env`, `os.getenv()`, and a fallback using `echo $VAR`.

local M = {}

---Returns the value of an environment variable, if set and non-empty.
---Tries vim.env → os.getenv() → shell fallback.
---@param name string The name of the environment variable
---@return string|nil value The variable value if set, otherwise nil
function M.get(name)
  local val = vim.env[name]
  if type(val) == "string" and val ~= "" then
    return val
  end

  val = os.getenv(name)
  if type(val) == "string" and val ~= "" then
    vim.env[name] = val -- cache
    return val
  end

  -- Shell fallback
  local shell_val = vim.fn.system("echo $" .. name):gsub("%s+", "")
  if shell_val and shell_val ~= "" and shell_val ~= "$" .. name then
    vim.env[name] = shell_val
    return shell_val
  end

  return nil
end

---Checks if an environment variable is set and non-empty.
---@param name string The name of the environment variable
---@return boolean is_set True if the variable exists and is not empty
function M.has(name)
  return M.get(name) ~= nil
end

return M
