---@class UIStateManager
---@field invocation UIStateInvocation invocation editor state before UI activation
---@field capture_invocation_state fun(): nil Captures the current window and cursor position for later restoration
---@field reset fun(tbl?: "buffers"|"windows"|"invocation"): nil Resets part or all of the UI state
---@field get_invocation_win fun(): number|nil Returns the window ID of the invocation state
---@field get_invocation_cursor fun(): UIStateCursor|nil Returns the cursor
---
---@field buffers UIStateBuffers buffer handles by role
---@field windows UIStateWindows window handles by role
---@field get_windows fun(): number[]|nil Returns all window handles in the state table which are not nil
---@field get_valid_buffer fun(buf_name): number|nil Returns the buffer number for the given buffer name, if it is valid
---@field get_buffers fun(): number[]|nil Returns all buffer handles in the state table which are not nil
---
---@field list UIStateList list handles by role
---@field list_populated boolean|nil Indicates if the list window was populated at least once
---@field current_selected_repo_name string|nil The name of the currently selected repository
---@field last_selected_line integer|nil The last selected line number in the list
---
---@brief Tracks plugin-local buffer and window handles  REF: update description
---@description
---The UIStateManager module maintains references to buffer and window IDs
---used by different parts of the user interface such as preview, prompt,
---list, and background. These handles allow coordinated lifecycle management
---(creation, update, teardown) of UI components.

local M = {}

-- Utility Modules (Debugging)
local notify = require("reposcope.utils.debug").notify


---@class UIStateInvocation
---@field win integer|nil window ID before UI was opened
---@field cursor UIStateCursor cursor position before UI was opened

---@class UIStateCursor
---@field row integer|nil
---@field col integer|nil

---@type UIStateInvocation
M.invocation = {
  win = nil,
  cursor = {
    col = nil,
    row = nil,
  }
}


---Capture the current window and cursor position for later restoration.
---@return nil
function M.capture_invocation_state()
  M.invocation.win = vim.api.nvim_get_current_win()
  M.invocation.cursor.row, M.invocation.cursor.col = unpack(vim.api.nvim_win_get_cursor(M.invocation.win))
end


---Reset part or all of the UI state
---@param tbl? "buffers"|"windows"|"invocation" optional table to reset; if nil, all will be reset
---@return nil
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


---Return the window of the invocation state
---@return number|nil The window ID of the invocation state
function M.get_invocation_win()
  return M.invocation.win
end


---Returns the cursor of the invocation state
---@return table|nil The cursor position (row, col)
function M.get_invocation_cursor()
  return M.invocation.cursor
end

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


---Returns the buffer number for the given buffer name, if it is valid
---@param buf_name string The name of the buffer
---@return number|nil The buffer number if found and valid, or nil if not found or invalid
function M.get_valid_buffer(buf_name)
  local buf = M.buffers[buf_name]

  if buf and vim.api.nvim_buf_is_valid(buf) then
    return buf
  end

  notify("[reposcope] Buffer '" .. buf_name .. "' is not valid or does not exist.", 3)
  return nil
end


---Returns all buffer handles in the state table which are not nil
---@return number[]|nil List of active buffer handles
function M.get_buffers()
  local bufs = {}
  for _, buf in pairs(M.buffers) do
    if type(buf) == "number" then
      table.insert(bufs, buf)
    end
  end

  return #bufs > 0 and bufs or nil
end


---Returns all window handles in the state table which are not nil
---@return number[]|nil List of active window handles
function M.get_windows()
  local wins = {}
  for _, win in pairs(M.windows) do
    if type(win) == "number" then
      table.insert(wins, win)
    end
  end

  return #wins > 0 and wins or nil
end

-- HACK: list not in use right now, only the direct variables

---@class UIStateList
---@field list_populated boolean|nil Indicates if the list window was populated at least once
---@field current_selected_repo_name string|nil The name of the currently selected repository
---@field last_selected_line integer|nil The last selected line number in the list

---@type UIStateList
M.list = {
  list_populated = nil,
  current_selected_repo_name = nil,
  last_selected_line = nil
}

-- State variables related to the list and selection
---@type boolean|nil Indicates if the list was populated at least once
M.list_populated = nil

---@type string|nil The name of the currently selected repository -- HACK:
M.current_selected_repo_name = nil

---@type integer|nil The last selected line in the list
M.last_selected_line = nil

--TODO:  print above to values over period and check if the are equal odr defer any time

return M
