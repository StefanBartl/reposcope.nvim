---@module 'reposcope.controllers.repository_ui_loader'
---@brief Handles the UI logic after a successful repository fetch.
---@description
--- This module populates the repository list UI and optionally triggers
--- a README fetch for the first result. It operates purely on the UI level
--- and does not perform API requests or decode JSON.
--- Provider-agnostic: shared by every provider's repository manager.

---@class RepositoryUILoader : RepositoryUILoaderModule
local M = {}

-- Vim API
local defer_fn = vim.defer_fn
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
-- UI and State
local ui_state = require("reposcope.state.ui.ui_state")
local reset_selected_line = require("reposcope.ui.list.list_manager").reset_selected_line
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local repository_cache_get = require("reposcope.cache.repository_cache").get
local get_config_option = require("reposcope.config").get_option
local notify = require("reposcope.utils.debug").notify

---@private
---@internal
---Pre-caches READMEs for the top `config.readme_precache_count` results
--- (excluding the first, which `load_ui_after_fetch` already fetches via the
--- normal selected-line path) so scrolling through them feels instant. Each
--- call is independent and silent on failure — this is a background
--- optimization, not a user-facing action.
---@return nil
local function _precache_top_results()
  local count = get_config_option("readme_precache_count") or 0
  if count <= 1 then return end

  local items = repository_cache_get().items or {}
  local provider_controller = require("reposcope.controllers.provider_controller")

  for i = 2, math.min(count, #items) do
    provider_controller.prefetch_readme(items[i])
  end
end

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
        _precache_top_results()
      else
        notify("[reposcope] List buffer is not available. README fetch canceled.", 4)
      end
    end, 100)
  end)
end

return M
