--- @class Repository
--- @field name string Repository name
--- @field description string Repository description
--- @field html_url string Repository URL
--- @field readme_cache? string Cached README text

--- @class RepositoryResponse
--- @field total_count number Total number of repositories found
--- @field items Repository[] List of repositories

local M = {}

---@type RepositoryResponse
M.repositories = {}  -- Globaler Cache für JSON-Response

--- Speichert den JSON-Response der Repositories
---@param json RepositoryResponse
function M.set_repositories(json)
  M.repositories = json
end

--- Gibt den JSON-Cache zurück
---@return RepositoryResponse
function M.get_repositories()
  return M.repositories
end

--- Gibt ein Repository anhand des Namens zurück
---@param repo_name string
---@return Repository|nil
function M.get_repository(repo_name)
  for _, repo in ipairs(M.repositories.items or {}) do
    if repo.name == repo_name then
      return repo
    end
  end
  return nil
end

return M
