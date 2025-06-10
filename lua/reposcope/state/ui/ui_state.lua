---@module 'reposcope.state.ui.ui_state'
---@brief Tracks plugin-local buffer, window, and cursor state
---@description
---The UIStateManager module maintains references to buffer and window IDs
---used by different parts of the user interface such as preview, prompt,
---list, and background. It also tracks invocation context (cursor/window)
---and whether the UI list has been populated. These handles and states
---allow coordinated lifecycle management (creation, update, teardown).

---@class UIStateManager : UIStateManagerModule
local M = {}

-- Vim Utilities
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_get_current_win = vim.api.nvim_get_current_win
local nvim_win_get_cursor = vim.api.nvim_win_get_cursor
-- Utility Modules (Debugging)
local notify = require("reposcope.utils.debug").notify


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
  M.invocation.win = nvim_get_current_win()
  M.invocation.cursor.row, M.invocation.cursor.col = unpack(nvim_win_get_cursor(M.invocation.win))
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

  if buf and nvim_buf_is_valid(buf) then
    return buf
  end

  notify("[reposcope] Buffer '" .. buf_name .. "' is not valid or does not exist.", 3)
  return nil
end


---Returns all buffer handles in the state table which are not nil
---@return number[]|nil List of active buffer handles
function M.get_buffers()
  local bufs = {}

  for _, entry in pairs(M.buffers) do
    if type(entry) == "number" then
      table.insert(bufs, entry)

    elseif type(entry) == "table" then
      for _, sub in pairs(entry) do
        if type(sub) == "number" then
          table.insert(bufs, sub)
        end
      end
    end
  end

  return #bufs > 0 and bufs or nil
end



---Returns all window handles in the state table which are not nil
---@return number[]|nil List of active window handles
function M.get_windows()
  local wins = {}

  for _, entry in pairs(M.windows) do
    if type(entry) == "number" then
      table.insert(wins, entry)

    elseif type(entry) == "table" then
      for _, sub in pairs(entry) do
        if type(sub) == "number" then
          table.insert(wins, sub)
        end
      end
    end
  end

  return #wins > 0 and wins or nil
end



---@type UIStateList
M.list = {
  ---@type integer|nil The last selected line in the list
  last_selected_line = nil
}

-- State variable tracking if the repository list has ever been populated
---@type boolean|nil
---@private
local list_populated = nil


---Returns true if the repository list was populated at least once
---@return boolean
function M.is_list_populated()
  return list_populated == true
end


---Sets the internal list population state
---@param val boolean True if list has been populated
---@return nil
function M.set_list_populated(val)
  if type(val) ~= "boolean" then
    notify("[reposcope] set_list_populated: expected boolean, got " .. type(val), 4)
    return
  end
  list_populated = val
end

return M
