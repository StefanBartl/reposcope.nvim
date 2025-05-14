---@class RepositoryOwner
---@field login string Owner login name

---@class Repository
---@field name string Repository name
---@field description string Repository description
---@field html_url string Repository URL
---@field owner RepositoryOwner Owner of the repository
---@field default_branch? string The default branch of the repository (optional)
---@field readme_cache? string Cached README text

---@class RepositoryResponse
---@field total_count number Total number of repositories found
---@field items Repository[] List of repositories

---@class RepositoryManager
---@field set_repositories fun(json: RepositoryResponse): nil Stores the JSON response of repositories
---@field get_repositories fun(): RepositoryResponse Returns the cached JSON response
---@field get_repository fun(repo_name: string): Repository|nil Returns a repository by its name
---@field get_selected_repo fun(): Repository|nil Retrieves the currently selected repository
---@field are_loaded fun(): boolean Returns, if repositories are loaded in ram cache
local M = {}

local notify = require("reposcope.utils.debug").notify

---@type RepositoryResponse
M.repositories = { total_count = 0, items = {} } -- Global cache for JSON response

---Stores the JSON response of repositories
---@param json RepositoryResponse
---@return nil
function M.set_repositories(json)
  M.repositories.total_count = json.total_count or 0
  M.repositories.items = json.items or {}

  ---DEBUG: proof and securing repository fields
  -- Problem: `userdata` type in API data causes errors when concatenated.  
  -- Solution: Ensure all API fields are strings, using `tostring()` if needed.
  for _, repo in ipairs(M.repositories.items) do
    if type(repo.name) ~= "string" then
      notify("[reposcope] Warning: Repository name is not a string. Type: " .. type(repo.name), 3)
      repo.name = tostring(repo.name or "No name")
    end

    if type(repo.description) ~= "string" and repo.description ~= nil then
      notify("[reposcope] Warning: Repository description is not a string. Type: " .. type(repo.description), 3)
      repo.description = tostring(repo.description or "No description")
    end

    if type(repo.owner) == "table" and type(repo.owner.login) ~= "string" then
      notify("[reposcope] Warning: Repository owner login is not a string. Type: " .. type(repo.owner.login), 3)
      repo.owner.login = tostring(repo.owner.login or "Unknown")
    elseif type(repo.owner) ~= "table" then
      notify("[reposcope] Warning: Repository owner is not a table. Type: " .. type(repo.owner), 3)
      repo.owner = { login = "Unknown" }
    end
  end
end

---Returns the cached JSON response
function M.get_repositories()
  return M.repositories
end

---Returns a repository by its name
---@param repo_name string Repository name to search for
function M.get_repository(repo_name)
  for _, repo in ipairs(M.repositories.items or {}) do
    if repo.name == repo_name then
      return repo
    end
  end
  return nil
end

---Retrieves the currently selected repository based on the list entry.
function M.get_selected_repo()
  local json_data = M.get_repositories()
  if not json_data or not json_data.items then
    return nil
  end

  local lines = require("reposcope.ui.list.repositories")
  local ui_state = require("reposcope.state.ui")

  -- Read the currently selected line in the list
  local selected_line = lines.current_line
  if not selected_line then return nil end

  -- Read the repository entry in the list (format: "username/reponame: description")
  local line_text = vim.api.nvim_buf_get_lines(ui_state.buffers.list, selected_line - 1, selected_line, false)[1]
  if not line_text then return nil end

  -- Expected format: "username/reponame: description"
  local owner, repo_name = line_text:match("([^/]+)/([^:]+)")
  if not owner or not repo_name then
    notify("[reposcope] Invalid list format: " .. line_text, 4)
    return nil
  end

  -- Search for the repository by owner and name in the cached list
  for _, repo in ipairs(json_data.items) do
    if repo.owner and repo.owner.login == owner and repo.name == repo_name then
      return repo
    end
  end

  notify("[reposcope] Repository not found: " .. owner .. "/" .. repo_name, 3)
  return nil
end

---Test function, whih returns if repositories are loaded in RAM
function M.are_loaded()
  local json_data = M.get_repositories()
  if not json_data or not json_data.items then
    return false
  end

  return true
end

return M
