
local M = {}

local generate_uuid = require("reposcope.utils.core").generate_uuid
local request_state = require("reposcope.state.requests_state")
local current_provider = require("reposcope.config").get_option("provider")

local providers = {
  github = require("reposcope.providers.github.entrypoint"),
  -- gitlab = require("reposcope.providers.gitlab.entrypoint"),
  -- codeberg = require("reposcope.providers.codeberg.entrypoint"),
}

function M.fetch_readme_for_selected()
  local uuid = generate_uuid()
  request_state.start_request(uuid)
  providers[current_provider].readme_manager.fetch_for_selected(uuid)
end

function M.fetch_repositories(query)
  local uuid = generate_uuid()
  request_state.register_request(uuid)
  providers[current_provider].repo_fetcher.fetch_repositories(query, uuid)
end

return M
