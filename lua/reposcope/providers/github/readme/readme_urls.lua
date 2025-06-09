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

---Returns both the raw content and API URLs for a given repository README.
---Accepts either explicit `owner`, `repo`, `branch` or a GitHub blob URL.
---@param owner string GitHub owner OR full blob URL (e.g. https://github.com/user/repo/blob/branch/README.md)
---@param repo? string Repository name
---@param branch? string Branch name (optional, defaults to "main")
---@return ReadmeURLs
function M.get_urls(owner, repo, branch)
  -- Case 1: full GitHub blob URL
  if owner:match("^https://github.com/.+/blob/.+/README%.md$") then
    local o, r, b = owner:match("github%.com/([^/]+)/([^/]+)/blob/([^/]+)/README%.md")
    assert(o and r and b, "Invalid GitHub blob URL")
    owner, repo, branch = o, r, b
  else
    -- Normal argument-based mode
    assert(type(owner) == "string" and owner ~= "", "Invalid owner")
    assert(type(repo) == "string" and repo ~= "", "Invalid repository name")
    branch = branch or "main"
    assert(type(branch) == "string" and branch ~= "", "Invalid branch")
  end

  local raw_url = "https://raw.githubusercontent.com/" .. owner .. "/" .. repo .. "/" .. branch .. "/README.md"
  local api_url = "https://api.github.com/repos/" .. owner .. "/" .. repo .. "/contents/README.md"

  return {
    raw = raw_url,
    api = api_url,
  }
end

return M

