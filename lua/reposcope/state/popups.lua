---@class PopupsStateManager
---@field CloneModule ClonePopupState State for the providers/clone.lua module --NOTE: This is how annotation could be
---@field ensure_clean_state fun(tbl: table): nil Ensures the state of a given table is clean
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

---Ensures the state of a given table is clean
--- - Unmaps all keymaps for the buffer
--- - Closes the window
--- - Resets the buffer and window to nil
---@param tbl table The table to ensure is clean
---@return nil
function M.ensure_clean_state(tbl)
  if type(tbl) ~= "table" then
    return
  end
  if tbl.buf and vim.api.nvim_buf_is_valid(tbl.buf) then
    require("reposcope.keymaps").force_unmap_all(tbl.buf)
    vim.api.nvim_buf_delete(tbl.buf, { force = true })
  end

  tbl = {
    buf = nil,
    win = nil,
  }
end

return M
