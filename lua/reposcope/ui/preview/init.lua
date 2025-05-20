--- @class PreviewUI
--- @brief Initializes the preview window and injects the startup banner.
--- @description
--- This module sets up the preview window as part of the Reposcope UI.
--- It ensures the preview buffer and window are created, and then populates
---
--- the buffer with a centered welcome banner. This is typically called
--- during the initial UI setup and does not display any repository content.
---
--- Responsibilities:
--- - Create and display the preview window
--- - Inject a banner at startup
---
--- This module delegates layout logic and content injection to `preview_window`
--- and `preview_manager` respectively.
---
--- @field open_window fun(): nil Opens the preview window and injects the default banner

local M = {}

-- Preview UI Components (Banner, Layout, Buffer Injection)
local preview_window = require("reposcope.ui.preview.preview_window")
local preview_manager = require("reposcope.ui.preview.preview_manager")
-- Application State
local ui_state = require("reposcope.state.ui.ui_state")


--- Opens the preview window and injects the default banner.
--- @return nil
function M.open_window()
  preview_window.open_window()
  local buf = ui_state.buffers.preview
  if buf then
    preview_manager.inject_banner(buf)
  end
end

return M
