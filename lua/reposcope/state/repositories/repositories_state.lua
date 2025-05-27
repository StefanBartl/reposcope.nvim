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
---@field list string[] List of all repositories with most important informations

---@class RepositoryState
---@brief Manages the current state of loaded repositories in the application.
---@description 
--- The `RepositoryState` module is responsible for managing the active state of repositories
--- that are loaded in the application. Unlike a cache, this state is not persistent and 
--- is dynamically updated whenever a new search query is performed. The state is cleared 
--- or overwritten with each new search result, representing the current, active view 
--- of repositories in the application.
---
--- The module provides functions to set, retrieve, and clear the current state of repositories.
--- This ensures that the list of repositories always reflects the most recent search result.
--- Unlike a cache, which might store multiple versions of data for reuse, this state only
--- stores the current result set.
---@field set_repositories fun(json: RepositoryResponse): nil Stores the JSON response of repositories, sanitizes each repo entry and builds lines
---@field get_repositories fun(): RepositoryResponse Returns the cached JSON response
---@field get_repository fun(repo_name: string): Repository|nil Returns a repository by its name
---@field get_selected_repo fun(): Repository|nil Retrieves the currently selected repository
---@field get_repositories_list fun(): string[] Returns the list of actual repositories or table with empty string if thte list is empty
---@field clear_state fun(): nil Clears the repository state
local M = {}

-- State Management (UI State, List Window)
local ui_state = require("reposcope.state.ui.ui_state")
local list_window = require("reposcope.ui.list.list_window")
-- Debugging & Utility
local notify = require("reposcope.utils.debug").notify
local ensure_string = require("reposcope.utils.core").ensure_string
local api = vim.api

---@type RepositoryResponse
M.repositories = { total_count = 0, items = {}, list = {} }


---Stores the JSON response of repositories, sanitizes each repo entry and builds lines
---@param json RepositoryResponse
---@return nil
function M.set_repositories(json)
  M.repositories.total_count = json.total_count or 0
  M.repositories.items = json.items or {}
  M.repositories.list = {}

  for _, repo in ipairs(M.repositories.items) do
    ---@type string
    local name = ensure_string(repo.name)
    if name == "" then
      notify("[reposcope] Repository missing valid 'name', inserted fallback", 2)
      name = "No name"
    end

    ---@type string
    local owner = ensure_string(repo.owner and repo.owner.login)
    if owner == "" then
      notify("[reposcope] Repository missing valid 'owner.login', inserted fallback", 2)
      owner = "Unknown"
    end

    ---@type string
    local desc = ensure_string(repo.description)
    if desc == "" then
      desc = "No description"
    end

    local line = owner .. "/" .. name .. ": " .. desc
    table.insert(M.repositories.list, line)
  end

  for i, line in ipairs(M.repositories.list) do
    if type(line) ~= "string" then
      notify(string.format("[reposcope] [dev] Repo list line %d is not a string: %s", i, type(line)), 4)
      notify(vim.inspect(line), 4)
    end
  end
end


---Returns the cached JSON response
---@return RepositoryResponse
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


---Returns the list of the actual repositories or table with empty string if thte list is empty
---@return string[]
function M.get_repositories_list()
  local list = M.repositories.list

  if #list == 0 then
    list = { "" }
  end

  return list
end


---Retrieves the currently selected repository based on the list entry.
---@return Repository|nil
function M.get_selected_repo()
  local json_data = M.get_repositories()
  if not json_data or not json_data.items or json_data.total_count == 0 then
    return nil
  end

  -- Read the currently selected line in the list
  local selected_line = list_window.highlighted_line
  if not selected_line then
    notify("[reposcope] No list item is currently selected.", 3)
    return nil
  end

  -- Avoid accessing a row that does not yet exist
  local line_count = api.nvim_buf_line_count(ui_state.buffers.list)
  if selected_line > line_count then
    notify(string.format("[reposcope] Selected line (%d) exceeds list buffer line count (%d)", selected_line, line_count), 3)
    return nil
  end

  -- Read the repository entry in the list (format: "username/reponame: description")
  local line_text = api.nvim_buf_get_lines(ui_state.buffers.list, selected_line - 1, selected_line, false)[1]
  if not line_text or line_text == "" then
    notify(string.format("[reposcope] No content found at line %d in list buffer.", selected_line), 3)
    return nil
  end

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


--- Clears the repository state
---@return nil
function M.clear_state()
  M.repositories = { total_count = 0, items = {}, list = {} }
  notify("[reposcope] Repository state cleared.", 2)
end

return M
