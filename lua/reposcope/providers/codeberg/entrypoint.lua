---@module 'reposcope.providers.codeberg.entrypoint'
---@brief Central entrypoint for Codeberg provider components
---@description
--- This module acts as a central access point for all Codeberg-related provider functionality.

---@type ProviderEntrypoint
return {
  readme_manager = require("reposcope.providers.codeberg.readme.readme_manager"),
  repo_fetcher = require("reposcope.providers.codeberg.repositories.repository_manager"),
  cloner = require("reposcope.providers.codeberg.clone.clone_manager"),
  query_builder = require("reposcope.providers.codeberg.query_builder"),
}
