---@class PopupsStateManager
---@field CloneModule ClonePopupState State for the providers/clone.lua module --NOTE: This is how annotation could be
local M = {}

---@class ClonePopupState
---@field buf number|nil Buffer of the clone popup
---@field win number|nil Window of the clone popup
M.clone = {
  buf = nil,
  win = nil,
}

---@class StatsPopupState
---@field buf number|nil Buffer of the stats popup
---@field win number|nil Window of the stats popup
M.stats = {
  buf = nil,
  win = nil,
}

return M
