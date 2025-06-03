---@module 'reposcope.providers.github.readme.readme_urls'
---@brief Constructs URLs to fetch repository README files
---@description
--- This module provides utility functions for generating standardized URLs for fetching
--- README files from GitHub. It supports both the RAW GitHub content URL and the GitHub
--- API endpoint used to fetch metadata (and encoded content).
--- 
--- It is used by the readme_fetcher and manager modules to construct targets for HTTP requests.

---@class ReadmeUrlBuilder : ReadmeUrlBuilderModule
local M = {}


---Returns both the raw content and API URLs for a given repository README
---@param owner string The owner of the repository
---@param repo string The repository name
---@param branch? string The branch to target (usually "main" or "master", defaults to 'main' if nil)
---@return ReadmeURLs
function M.get_urls(owner, repo, branch)
  assert(type(owner) == "string" and owner ~= "", "Invalid owner")
  assert(type(repo) == "string" and repo ~= "", "Invalid repository name")
  branch = branch or "main"
  assert(type(branch) == "string" and branch ~= "", "Invalid branch")

  local raw_url = string.format("https://raw.githubusercontent.com/%s/%s/%s/README.md", owner, repo, branch)
  local api_url = string.format("https://api.github.com/repos/%s/%s/contents/README.md", owner, repo)

  return { raw_url, api_url }
end

return M
