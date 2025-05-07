---@class PrintUtilities Print utilities for inspecting UI-related buffers and windows.
---@field print_invocation_state fun(): nil Prints the current UI invocation context (window and cursor).
---@field print_windows fun(): nil Prints all registered window handles in the UI state.
---@field print_buffers fun(): nil Prints all registered buffer handles in the UI state.
local M = {}

---Prints the current UI invocation context (window and cursor).
function M.print_invocation_state()
  local state = require("reposcope.state.ui")
  print("invocation list:")
  print("Window:", state.invocation.win)
  print("Cursor row/col:", state.invocation.cursor.row, state.invocation.cursor.col)
end

---Prints all registered window handles in the UI state.
function M.print_windows()
  print("Window list:")
  local state = require("reposcope.state.ui")
  for name, win in pairs(state.windows) do
    print(name, win)
  end
end

---Prints all registered buffer handles in the UI state.
function M.print_buffers()
  print("Buffer list:")
  local state = require("reposcope.state.ui")
  for name, buf in pairs(state.buffers) do
    print(name, buf)
  end
end

return M
