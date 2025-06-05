---@module 'reposcope.utils.error'
---@brief Central error handling and wrapping system
---@description
--- Provides a standardized way to handle errors across the application.
--- Implements the safe_call pattern as specified in the architecture rules.

---@class ErrorUtils : ErrorUtilsModule
local M = {}

---Wraps a function call in a standardized error handling pattern
---@param fn fun(...): any The function to call
---@param ... any Arguments to pass to the function
---@return Result
function M.safe_call(fn, ...)
  local args = { ... }
  local ok, result = pcall(function()
    return fn(unpack(args))
  end)

  if not ok then
    return {
      ok = false,
      result = nil,
      err = result
    }
  end

  return {
    ok = true,
    result = result,
    err = nil
  }
end

---Creates a new error object
---@param type ErrorType
---@param message string
---@param details? table
---@return Error
function M.new_error(type, message, details)
  return {
    type = type,
    message = message,
    details = details
  }
end

return M
