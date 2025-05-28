---@class ProviderController
---@brief Dispatches actions to the currently selected provider implementation.
---@description
--- This controller routes generic operations like `fetch_repositories`, `fetch_readme_for_selected`,
--- or `clone_repository` to the currently selected provider (e.g., GitHub, GitLab, Codeberg).
--- It provides a stable interface that abstracts away provider-specific logic and unifies
--- request tracking and dispatching logic.
---
--- All dispatched functions support UUID-based request tracking via the RequestStateManager.
---@field fetch_readme_for_selected fun(): nil Triggers a README fetch using the active provider
---@field fetch_repositories fun(query: string): nil Triggers a repository search query using the active provider
---@field prompt_and_clone fun(): nil Prompts user for path and triggers clone using the active provider
local M = {}

---@description Forward declaration for private helper
local get_provider

-- Utilities and Core
local generate_uuid = require("reposcope.utils.core").generate_uuid
-- Request Tracking
local request_state = require("reposcope.state.requests_state")
-- Config Access
local get_clone_dir = require("reposcope.config").get_clone_dir
-- Debug Output
local notify = require("reposcope.utils.debug").notify


-- Provider Entry Points
local providers = {
  github = require("reposcope.providers.github.entrypoint"),
  -- gitlab = require("reposcope.providers.gitlab.entrypoint"),
  -- codeberg = require("reposcope.providers.codeberg.entrypoint"),
}


---Dispatches a README fetch request to the active provider.
---A UUID is generated and marked active via request_state.
---@return nil
function M.fetch_readme_for_selected()
  local uuid = generate_uuid()
  request_state.register_request(uuid)
  providers[get_provider()].readme_manager.fetch_for_selected(uuid)
end


---Dispatches a repository fetch (search) query to the active provider.
---UUID is registered for later activation and deduplication.
---@param query string The search query string for repositories
---@return nil
function M.fetch_repositories(query)
  local uuid = generate_uuid()
  request_state.register_request(uuid)
  providers[get_provider()].repo_fetcher.fetch_repositories(query, uuid)
end


---Prompts the user for a directory and dispatches a clone request
---to the active provider with the given target path.
---@return nil
function M.prompt_and_clone()
  local clone_dir = get_clone_dir()
  vim.ui.input({
    prompt = "Set clone path: ",
    default = clone_dir,
    completion = "file",
  }, function(input)
    if input then
      local uuid = generate_uuid()
      request_state.register_request(uuid)
      vim.schedule(function ()
        providers[get_provider()].cloner.clone_repository(input, uuid)
      end)
    else
      notify("[reposcope] Cloning canceled.", 2)
    end
  end)
end


---@private
---Resolves the currently selected provider string from config
---@return string The active provider identifier (e.g., "github")
function get_provider()
  return require("reposcope.config").get_option("provider")
end

return M
