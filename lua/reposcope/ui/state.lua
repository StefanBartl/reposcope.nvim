--REF: Get rid of the long names

--- @class UIState
--- @field previous UIStatePrevious previous editor state before UI activation
--- @field fers UIStateBuffers buffer handles by role
--- @field windows UIStateWindows window handles by role
--- @brief Tracks plugin-local fer and window handles for UI elements.
--- @description
--- The UIState module maintains references to buffer and window IDs
--- used by different parts of the user interface such as preview, prompt,
--- list, and background. These handles allow coordinated lifecycle management
--- (creation, update, teardown) of UI components.

--- @class UIStatePrevious
--- @field win integer|nil window ID before UI was opened
--- @field cursor UIStateCursor cursor position before UI was opened

--- @class UIStateCursor
--- @field row integer|nil
--- @field col integer|nil

--- @class UIStateBuffers
--- @field backg integer|nil
--- @field preview integer|nil
--- @field prompt integer|nil
--- @field list integer|nil

--- @class UIStateWindows
--- @field backg integer|nil
--- @field preview integer|nil
--- @field prompt integer|nil
--- @field list integer|nil

local M = {}


---@type UIStatePrevious
M.previous = {
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

--- Reset part or all of the UI state
--- @param tbl? "buffers"|"windows"|"previous" optional table to reset; if nil, all will be reset
function M.reset(tbl)
  if tbl == nil or tbl == "buffers" then
    for k in pairs(M.buffers) do
      M.buffers[k] = nil
    end
    print("buffers reset")
  end

  if tbl == nil or tbl == "windows" then
    for k in pairs(M.windows) do
      M.windows[k] = nil
    end
    print("windows reset")
  end

  if tbl == nil or tbl == "previous" then
    M.previous.win = nil
    M.previous.cursor.row = nil
    M.previous.cursor.col = nil
    print("previous reset")
  end

  if tbl ~= nil and tbl ~= "buffers" and tbl ~= "windows" and tbl ~= "previous" then
    print("Invalid argument passed to M.reset():", tbl)
  end
end

--- Prints out all windows in state table which are not nil
--- @return nil
function M.print_windows()
  print("Window list:")
  for name, win in pairs(M.windows) do
    print(name, win)
  end
end

function M.get_windows()
  local wins = {}
  for _, win in pairs(M.windows) do
    table.insert(wins, win)
  end
  return wins
end

--- Prints out all buffers in state table which are not nil
--- @return nil
function M.print_buffers()
  print("Buffer list:")
  for name, buf in pairs(M.buffers) do
    print(name, buf)
  end
end

--- Prints out all values from previous state table (reflects local caller of the ui) which are not nil
--- @return nil
function M.print_previous()
  print("Previous list:")
  print("Window:", M.previous.win)
  print("Cursor row/col:", M.previous.cursor.row, M.previous.cursor.col)
end

return M
