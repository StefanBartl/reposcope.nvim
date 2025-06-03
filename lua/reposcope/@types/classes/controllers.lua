---@module 'reposcope.@types.classes.controllers'
---@brief Type definitions for UI and provider controller modules

---@class ListControllerModule
---@field display_repositories fun(): nil Displays the list of repositories from state.

---@class ProviderControllerModule
---@field fetch_readme_for_selected fun(): nil Triggers a README fetch using the active provider
---@field fetch_repositories fun(query: string): nil Triggers a repository search query using the active provider
---@field prompt_and_clone fun(): nil Prompts user for path and triggers clone using the active provider
