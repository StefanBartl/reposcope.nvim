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

--- Reset all fer and window handles to nil.
--- @return nil
function M.reset()
  for k in pairs(M.fers) do
    M.fers[k] = nil
  end
  for k in pairs(M.windows) do
    M.windows[k] = nil
  end
end

return M
