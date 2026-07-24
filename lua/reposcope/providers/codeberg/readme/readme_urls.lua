---@module 'reposcope.providers.codeberg.readme.readme_urls'
---@brief Constructs URLs to fetch repository README files from Codeberg
---@description
--- Raw URL uses Codeberg's (Gitea) `/raw/branch/<branch>/<path>` route; the
--- API URL uses the Gitea contents endpoint, which mirrors GitHub's shape —
--- JSON with a base64-encoded `content` field.

---@class CodebergReadmeUrlBuilder : ReadmeUrlBuilderModule
local M = {}


---Returns both the raw content and API URLs for a given repository README.
---@param owner string Codeberg owner (user or org)
---@param repo? string Repository name
---@param branch? string Branch name (optional, defaults to "main")
---@return ReadmeURLs
function M.get_urls(owner, repo, branch)
  assert(type(owner) == "string" and owner ~= "", "Invalid owner")
  assert(type(repo) == "string" and repo ~= "", "Invalid repository name")
  branch = branch or "main"

  local raw_url = "https://codeberg.org/" .. owner .. "/" .. repo .. "/raw/branch/" .. branch .. "/README.md"
  local api_url = "https://codeberg.org/api/v1/repos/" .. owner .. "/" .. repo .. "/contents/README.md?ref=" .. branch

  return {
    raw = raw_url,
    api = api_url,
  }
end

return M
