---@module 'reposcope.providers.gitlab.readme.readme_urls'
---@brief Constructs URLs to fetch repository README files from GitLab
---@description
--- Raw URL uses GitLab's public web raw-file route; the API URL uses the
--- repository files endpoint, addressed by a URL-encoded `owner/repo` path
--- (accepted by GitLab in place of the numeric project ID), returning JSON
--- with a base64-encoded `content` field.

---@class GitlabReadmeUrlBuilder : ReadmeUrlBuilderModule
local M = {}

local urlencode = require("reposcope.utils.encoding").urlencode


---Returns both the raw content and API URLs for a given repository README.
---@param owner string GitLab namespace (owner/group)
---@param repo string Repository (project) name
---@param branch? string Branch name (optional, defaults to "main")
---@return ReadmeURLs
function M.get_urls(owner, repo, branch)
  assert(type(owner) == "string" and owner ~= "", "Invalid owner")
  assert(type(repo) == "string" and repo ~= "", "Invalid repository name")
  branch = branch or "main"

  local raw_url = "https://gitlab.com/" .. owner .. "/" .. repo .. "/-/raw/" .. branch .. "/README.md"
  local api_url = "https://gitlab.com/api/v4/projects/" .. urlencode(owner .. "/" .. repo)
      .. "/repository/files/README.md?ref=" .. urlencode(branch)

  return {
    raw = raw_url,
    api = api_url,
  }
end

return M
