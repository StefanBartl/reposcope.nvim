---@class PopupsStateManager
---@field stats StatsPopupState State for buffer and window for the stats popup
local M = {}

---@class StatsPopupState
---@field buf number|nil Buffer of the stats popup
---@field win number|nil Window of the stats popup
M.stats = {
  buf = nil,
  win = nil,
}

return M
