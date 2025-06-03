---@module 'reposcope.ui.preview.init'
--- @brief Initializes the preview window and injects the startup banner
--- @description
---This module sets up the preview window as part of the Reposcope UI.
---It ensures the preview buffer and window are created, and then populates
---
---the buffer with a centered welcome banner. This is typically called
---during the initial UI setup and does not display any repository content

--- @class PreviewUI : PreviewUIModule
local M = {}

-- Vim Utilities
local schedule = vim.schedule
-- Preview UI Components
local open_window = require("reposcope.ui.preview.preview_window").open_window
local inject_banner = require("reposcope.ui.preview.preview_manager").inject_banner
local update_preview = require("reposcope.ui.preview.preview_manager").update_preview
-- Application State
local ui_state = require("reposcope.state.ui.ui_state")
-- Cache Management
local repo_cache_get_selected = require("reposcope.cache.repository_cache").get_selected
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Initialize the preview window and injects either the default banner or the last selected README.
---@return nil
function M.initialize()
  if not open_window() then
    notify("[reposcope] Preview initialization failed.", 4)
    return
  end

  local buf = ui_state.buffers.preview
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Preview buffer invalid, initialization failed.", 4)
    return
  end

  if ui_state.is_list_populated() then
    schedule(function()
      local selected_repo = repo_cache_get_selected()
      if selected_repo and selected_repo.name then
          update_preview(selected_repo.name)
      end
    end)
  else
    inject_banner(buf)
  end
end

return M
