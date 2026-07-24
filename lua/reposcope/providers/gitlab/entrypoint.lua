---@module 'reposcope.providers.gitlab.entrypoint'
---@brief Central entrypoint for GitLab provider components
---@description
--- This module acts as a central access point for all GitLab-related provider functionality.

---@type ProviderEntrypoint
return {
  readme_manager = require("reposcope.providers.gitlab.readme.readme_manager"),
  repo_fetcher = require("reposcope.providers.gitlab.repositories.repository_manager"),
  cloner = require("reposcope.providers.gitlab.clone.clone_manager"),
  query_builder = require("reposcope.providers.gitlab.query_builder"),
}
