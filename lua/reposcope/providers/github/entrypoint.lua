---@module 'reposcope.providers.github.entrypoint'
---@brief Central entrypoint for GitHub provider components
---@description
--- This module acts as a central access point for all GitHub-related provider functionality.

return {
  readme_manager = require("reposcope.providers.github.readme.readme_manager"),
  repo_fetcher = require("reposcope.providers.github.repositories.repository_manager"),
  cloner = require("reposcope.providers.github.clone.clone_manager"),
}

