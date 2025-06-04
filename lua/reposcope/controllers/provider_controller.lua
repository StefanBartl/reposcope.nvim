---@module 'reposcope.controllers.provider_controller'
---@brief Dispatches actions to the currently selected provider implementation.
---@description
--- This controller routes generic operations like `fetch_repositories`, `fetch_readme_for_selected`,
--- or `clone_repository` to the currently selected provider (e.g., GitHub, GitLab, Codeberg).
--- It provides a stable interface that abstracts away provider-specific logic and unifies
--- request tracking and dispatching logic.
---
--- All dispatched functions support UUID-based request tracking via the RequestStateManager.
---@class ProviderController : ProviderControllerModule
local M = {}

-- Vim Utilties
local schedule = vim.schedule
local ui_input = vim.ui.input
-- Utilities and Core
local generate_uuid = require("reposcope.utils.core").generate_uuid
-- Request Tracking
local register_request = require("reposcope.state.requests_state").register_request
-- Config Access
local get_config_option = require("reposcope.config").get_option
-- Debug Output
local notify = require("reposcope.utils.debug").notify


-- Provider Entry Points
local providers = {
  github = require("reposcope.providers.github.entrypoint"),
  -- gitlab = require("reposcope.providers.gitlab.entrypoint"),
  -- codeberg = require("reposcope.providers.codeberg.entrypoint"),
}


---@private
---Resolves the currently selected provider string from config
---@return string The active provider identifier (e.g., "github")
local function _get_provider()
  return require("reposcope.config").get_option("provider")
end


---Dispatches a README fetch request to the active provider.
---A UUID is generated and marked active via request_state.
---@return nil
function M.fetch_readme_for_selected()
  local uuid = generate_uuid()
  register_request(uuid)
  providers[_get_provider()].readme_manager.fetch_for_selected(uuid)
end


---Dispatches a repository fetch (search) query to the active provider.
---UUID is registered for later activation and deduplication.
---@param query string The search query string for repositories
---@return nil
function M.fetch_repositories_and_display(query)
  local uuid = generate_uuid()
  register_request(uuid)
  providers[_get_provider()].repo_fetcher.fetch_and_display(query, uuid)
end


---Prompts the user for a directory and dispatches a clone request
---to the active provider with the given target path.
---@return nil
function M.prompt_and_clone()
  local clone = get_config_option("clone")
  local clone_dir = (type(clone) == "table" and clone.std_dir) or "./"

  ui_input({
    prompt = "Set clone path: ",
    default = clone_dir,
    completion = "file",
  }, function(input)
    if input then
      local uuid = generate_uuid()
      register_request(uuid)
      schedule(function ()
        providers[_get_provider()].cloner.clone(input, uuid)
      end)
    else
      notify("[reposcope] Cloning canceled.", 2)
    end
  end)
end

return M
