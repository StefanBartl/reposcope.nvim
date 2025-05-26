--- @class PreviewUI
--- @brief Initializes the preview window and injects the startup banner
--- @description
---This module sets up the preview window as part of the Reposcope UI.
---It ensures the preview buffer and window are created, and then populates
---
---the buffer with a centered welcome banner. This is typically called
---during the initial UI setup and does not display any repository content
---
---Responsibilities:
---- Create and display the preview window
---- Inject a banner at startup
---
---@field initialize fun(): nil Initializes the preview window and injects either the default banner or the last selected README.

local M = {}

-- Preview UI Components (Banner, Layout, Buffer Injection)
local preview_window = require("reposcope.ui.preview.preview_window")
local preview_manager = require("reposcope.ui.preview.preview_manager")
-- Application State
local ui_state = require("reposcope.state.ui.ui_state")
local repositories_state = require("reposcope.state.repositories.repositories_state")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Initialize the preview window and injects either the default banner or the last selected README.
---@return nil
function M.initialize()
  if not preview_window.open_window() then
    notify("[reposcope] Preview initialization failed.", 4)
    return
  end

  local buf = ui_state.buffers.preview
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    notify("[reposcope] Preview buffer invalid, initialization failed.", 4)
    return
  end

  if ui_state.is_list_populated() then
    vim.schedule(function()
      local selected_repo = repositories_state.get_selected_repo()
      if selected_repo and selected_repo.name then
          preview_manager.update_preview(selected_repo.name)
      end
    end)
  else
    preview_manager.inject_banner(buf)
  end
end

return M
