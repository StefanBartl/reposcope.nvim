---@class UIState
---@field invocation UIStateInvocation invocation editor state before UI activation
---@field buffers UIStateBuffers buffer handles by role
---@field windows UIStateWindows window handles by role
---@brief Tracks plugin-local buffer and window handles for UI elements.
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
---@field list integer|nil
---@field clone integer|nil

---@class UIStateWindows
---@field backg integer|nil
---@field preview integer|nil
---@field prompt integer|nil
---@field list integer|nil
---@field clone integer|nil

---@class UIStateManager
---@field capture_invocation_state fun(): nil Captures the current window and cursor position for later restoration
---@field reset fun(tbl?: "buffers"|"windows"|"invocation"): nil Resets part or all of the UI state
---@field get_windows fun(): number[]|nil Returns all window handles in the state table which are not nil
---@field get_buffers fun(): number[]|nil Returns all buffer handles in the state table which are not nil
---@field get_invocation_win fun(): number|nil Returns the window ID of the invocation state
---@field get_invocation_cursor fun(): UIStateCursor|nil Returns the cursor of the invocation state
local M = {}

local notify = require("reposcope.utils.debug").notify

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
  list = nil,
}

---@type UIStateWindows
M.windows = {
  backg = nil,
  preview = nil,
  prompt = nil,
  list = nil,
}



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
    notify("buffers reset")
  end

  if tbl == nil or tbl == "windows" then
    for k in pairs(M.windows) do
      M.windows[k] = nil
    end
    notify("windows reset")
  end

  if tbl == nil or tbl == "invocation" then
    M.invocation.win = nil
    M.invocation.cursor.row = nil
    M.invocation.cursor.col = nil
    notify("invocation reset")
  end

  if tbl ~= nil and tbl ~= "buffers" and tbl ~= "windows" and tbl ~= "invocation" then
    notify("Invalid argument passed")
  end
end

---Returns all window handles in the state table which are not nil
function M.get_windows()
  if not M.windows then
    notify("[reposcope] No state.windows table set", vim.log.levels.DEBUG)
    return nil
  end

  local wins = {}
  for _, win in pairs(M.windows) do
    if type(win) == "number" then
      table.insert(wins, win)
    end
  end

  if #wins == 0 then
    notify("[reposcope] No valid window entries in state.windows", vim.log.levels.DEBUG)
    return nil
  end

  return wins
end

---Returns all buffer handles in the state table which are not nil
function M.get_buffers()
  if not M.buffers then
    notify("[reposcope] No state.buffers table set", vim.log.levels.DEBUG)
    return nil
  end

  local bufs = {}
  for _, buf in pairs(M.buffers) do
    if type(buf) == "number" then
      table.insert(bufs, buf)
    end
  end

  if #bufs == 0 then
    notify("[reposcope] No valid buffer entries in state.buffers", vim.log.levels.DEBUG)
    return nil
  end

  return bufs
end

---Return the window of the invocation state
function M.get_invocation_win()
  if not M.invocation or not M.invocation.win then
    notify("[reposcope] No invocation window set", vim.log.levels.DEBUG)
    return nil
  end
  return M.invocation.win
end

---Returns the cursor of the invocation state
function M.get_invocation_cursor()
  if not M.invocation or not M.invocation.cursor then
    notify("[reposcope] No invocation cursor set", vim.log.levels.DEBUG)
    return nil
  end
  return M.invocation.cursor
end

return M
