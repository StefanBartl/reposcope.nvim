---@module 'reposcope.providers.github.repositories.repository_ui_loader'
---@brief Handles the UI logic after a successful GitHub repository fetch.
---@description
--- This module populates the repository list UI and optionally triggers
--- a README fetch for the first result. It operates purely on the UI level
--- and does not perform API requests or decode JSON.

---@class GithubRepositoryUILoader : GithubRepositoryUILoaderModule
local M = {}

-- Vim API
local defer_fn = vim.defer_fn
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
-- UI and State
local ui_state = require("reposcope.state.ui.ui_state")
local reset_selected_line = require("reposcope.ui.list.list_manager").reset_selected_line
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local notify = require("reposcope.utils.debug").notify


---Initializes the list UI and optionally triggers README loading
---@return nil
function M.load_ui_after_fetch()
  vim.schedule(function()
    reset_selected_line()
    display_repositories()

    -- Defer README trigger slightly to ensure list is visible
    defer_fn(function()
      local list_buf = ui_state.buffers.list
      if list_buf and nvim_buf_is_valid(list_buf) then
        ui_state.list.last_selected_line = 1
        notify("[reposcope] Default list line set to first entry.", 2)

        require("reposcope.controllers.provider_controller").fetch_readme_for_selected()
      else
        notify("[reposcope] List buffer is not available. README fetch canceled.", 4)
      end
    end, 100)
  end)
end

return M
