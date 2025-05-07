--- @class Repository
--- @field name string Repository name
--- @field description string Repository description
--- @field html_url string Repository URL
--- @field readme_cache? string Path to cached README file

--- @class RepositoryResponse
--- @field total_count number Total number of repositories found
--- @field items Repository[] List of repositories

local M = {}

---@type RepositoryResponse
M.repositories = {} -- Global cache for JSON-response

return M
