---@module 'reposcope.state.popups.stats_popup'
---@brief UI state management for the statistics popup window

---@class  PopupsStateManager : PopupsStateManagerModule
local M = {}

M.stats = {
  buf = nil,
  win = nil,
}

return M
