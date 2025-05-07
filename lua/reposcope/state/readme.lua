local repositories = require("reposcope.state.repositories")

local M = {}

--- Caches die README für ein Repository direkt im RAM
---@param repo_name string Der Name des Repositories
---@param readme_text string Der Inhalt der README-Datei
function M.cache_readme(repo_name, readme_text)
  local repo = repositories.get_repository(repo_name)
  if repo then
    repo.readme_cache = readme_text
  else
    vim.notify("[reposcope] Repository not found: " .. repo_name, vim.log.levels.ERROR)
  end
end

--- Gibt die gecachte README zurück, wenn vorhanden
---@param repo_name string Der Name des Repositories
---@return string|nil
function M.get_readme(repo_name)
  local repo = repositories.get_repository(repo_name)
  return repo and repo.readme_cache or nil
end

return M
