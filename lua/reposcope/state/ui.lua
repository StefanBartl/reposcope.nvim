---@class UIState
---@field invocation UIStateInvocation invocation editor state before UI activation
---@field buffers UIStateBuffers buffer handles by role
---@field windows UIStateWindows window handles by role
---@field reset fun(tbl?: "buffers"|"windows"|"invocation"): nil
---@field get_windows fun(): number[] Returns all window handles in the state table which are not nil
---@field get_buffers fun(): number[] Returns all buffer handles in the state table which are not nil
---@field get_invocation_win fun(): number Returns the window of the invocation state
---@field get_invocation_cursor fun(): table Returns the cursor of the invocation state
---@field print_win_buf_state fun(): nil Prints all windows and buffers to the console
---@brief Tracks plugin-local buffer and window handles and also other state for UI elements.   HACK:
---@description
---The UIState module maintains references to buffer and window IDs
---used by different parts of the user interface such as preview, prompt,
---list, and background. These handles allow coordinated lifecycle management
---(creation, update, teardown) of UI components.

---@class UIStateInvocation
---@field win integer|nil window ID before UI was opened
---@field cursor UIStateCursor cursor position before UI was opened

---@class UIStateCursor
---@field row integer|nil
---@field col integer|nil

---@class UIStateBuffers
---@field backg integer|nil
---@field preview integer|nil
---@field prompt integer|nil
---@field prompt_prefix integer|nil
---@field list integer|nil
---@field readme_viewer integer|nil

---@class UIStateWindows
---@field backg integer|nil
---@field preview integer|nil
---@field prompt integer|nil
---@field prompt_prefix integer|nil
---@field list integer|nil
---@field readme_viewer integer|nil

---@class UIPromptLastInput
---@field actual_text string  Holds state for the prompt input 

---@class UIStateManager
---@field capture_invocation_state fun(): nil Captures the current window and cursor position for later restoration
---@field reset fun(tbl?: "buffers"|"windows"|"invocation"): nil Resets part or all of the UI state
---@field get_windows fun(): number[]|nil Returns all window handles in the state table which are not nil
---@field get_buffers fun(): number[]|nil Returns all buffer handles in the state table which are not nil
---@field get_invocation_win fun(): number|nil Returns the window ID of the invocation state
---@field get_invocation_cursor fun(): UIStateCursor|nil Returns the cursor of the invocation state
---@field print_win_buf_state fun(): nil Prints actual state for debugging to the console

local M = {}

local debug = require("reposcope.utils.debug")
local repo_state = require("reposcope.state.repositories")

---@type UIStateInvocation
M.invocation = {
  win = nil,
  cursor = {
    col = nil,
    row = nil,
  }
}

---@type UIStateBuffers
M.buffers = {
  back = nil,
  preview = nil,
  prompt = nil,
  prompt_prefix = nil,
  list = nil,
  readme_viewer = nil,
}

---@type UIStateWindows
M.windows = {
  backg = nil,
  preview = nil,
  prompt = nil,
  prompt_prefix = nil,
  list = nil,
  readme_viewer = nil,
}

---@type UIPromptLastInput
M.prompt = {
  actual_text = ""
}

---Keep state if the list window was populated with repositories at least one 22:42
M.list_populated = nil
---Keep state which repositories is currently selected by the user in the repositoriy list by any user action
M.current_selected_repo_name = nil -- HACK:
---Saves the last selected line
M.last_selected_line = nil

--TODO:  print above to values over period and check if the are equal odr defer any time

--TODO: put in ui/utils

---Capture the current window and cursor position for later restoration.
function M.capture_invocation_state()
  M.invocation.win = vim.api.nvim_get_current_win()
  M.invocation.cursor.row, M.invocation.cursor.col = unpack(vim.api.nvim_win_get_cursor(M.invocation.win))
end

---Reset part or all of the UI state
---@param tbl? "buffers"|"windows"|"invocation" optional table to reset; if nil, all will be reset
function M.reset(tbl)
  if tbl == nil or tbl == "buffers" then
    for k in pairs(M.buffers) do
      M.buffers[k] = nil
    end
    debug.notify("buffers reset")
  end

  if tbl == nil or tbl == "windows" then
    for k in pairs(M.windows) do
      M.windows[k] = nil
    end
    debug.notify("windows reset")
  end

  if tbl == nil or tbl == "invocation" then
    M.invocation.win = nil
    M.invocation.cursor.row = nil
    M.invocation.cursor.col = nil
    debug.notify("invocation reset")
  end

  if tbl ~= nil and tbl ~= "buffers" and tbl ~= "windows" and tbl ~= "invocation" then
    debug.notify("Invalid argument passed")
  end
end

---Returns all window handles in the state table which are not nil
function M.get_windows()
  if not M.windows then
    debug.notify("[reposcope] No state.windows table set", 1)
    return nil
  end

  local wins = {}
  for _, win in pairs(M.windows) do
    if type(win) == "number" then
      table.insert(wins, win)
    end
  end

  if #wins == 0 then
    debug.notify("[reposcope] No valid window entries in state.windows", 1)
    return nil
  end

  return wins
end

---Returns all buffer handles in the state table which are not nil
function M.get_buffers()
  if not M.buffers then
    debug.notify("[reposcope] No state.buffers table set", 1)
    return nil
  end

  local bufs = {}
  for _, buf in pairs(M.buffers) do
    if type(buf) == "number" then
      table.insert(bufs, buf)
    end
  end

  if #bufs == 0 then
    debug.notify("[reposcope] No valid buffer entries in state.buffers", 1)
    return nil
  end

  return bufs
end

---Return the window of the invocation state
function M.get_invocation_win()
  if not M.invocation or not M.invocation.win then
    debug.notify("[reposcope] No invocation window set", 1)
    return nil
  end
  return M.invocation.win
end

---Returns the cursor of the invocation state
function M.get_invocation_cursor()
  if not M.invocation or not M.invocation.cursor then
    debug.notify("[reposcope] No invocation cursor set", 1)
    return nil
  end
  return M.invocation.cursor
end


---Prints actual state for debugging to the console
function M.print_win_buf_state()
  print("State Buffers:", vim.inspect(M.get_buffers()))
  print("State Windows:", vim.inspect(M.get_windows()))
end

return M
