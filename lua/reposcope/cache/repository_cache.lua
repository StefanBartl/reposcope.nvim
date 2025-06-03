---@module 'reposcope.cache.repository_cach'
---@brief Caches the most recent GitHub repository results in memory
---@description
--- This module temporarily caches the result of repository queries from the GitHub API.
--- It is not persistent and is overwritten on each new query. Other modules can
--- access and use this data (e.g., list UI, README fetcher, etc.)

---@class RepositoryCache : RepositoryCacheModule
local M = {}

-- Vim Utilities
local nvim_buf_get_lines = vim.api.nvim_buf_get_lines
local nvim_buf_line_count = vim.api.nvim_buf_line_count
-- State Management
local ui_state = require("reposcope.state.ui.ui_state")
local list_window = require("reposcope.ui.list.list_window")
-- Debugging & Utility
local notify = require("reposcope.utils.debug").notify
local ensure_string = require("reposcope.utils.core").ensure_string

---@type RepositoryResponse
M.repositories = { total_count = 0, items = {}, list = {} }


---@private
---@param repo table
---@param index integer
---@return table
local function _sanitize_repo(repo, index)
  ---@type string
  local name = ensure_string(repo.name)
  if name == "" then
    notify(string.format("[reposcope] Repository [%d] missing valid 'name', inserted fallback", index), 2)
    name = "No name"
  end

  ---@type string
  local owner = ensure_string(repo.owner and repo.owner.login)
  if owner == "" then
    notify(string.format("[reposcope] Repository [%d] missing valid 'owner.login', inserted fallback", index), 2)
    owner = "Unknown"
  end

  ---@type string
  local desc = ensure_string(repo.description)
  if desc == "" then
    desc = "No description"
  end

  repo.name = name
  repo.owner = repo.owner or {}
  repo.owner.login = owner
  repo.description = desc

  return repo
end


---@private
---@param repo table
---@return string
local function _build_repo_line(repo)
  return string.format("%s/%s: %s", repo.owner.login, repo.name, repo.description)
end


---@private
---@return nil
local function _validate_repo_list()
  for i, line in ipairs(M.repositories.list) do
    if type(line) ~= "string" then
      notify(string.format("[reposcope] [dev] Repo list line %d is not a string: %s", i, type(line)), 4)
      notify(vim.inspect(line), 4)
    end
  end
end


---Stores the JSON response of repositories, sanitizes each repo entry and builds lines
---@param json RepositoryResponse
---@return nil
function M.set(json)
  M.repositories.total_count = json.total_count or 0
  M.repositories.items = json.items or {}
  M.repositories.list = { [#M.repositories.items] = false } -- reserve cap 

  for i, repo in ipairs(M.repositories.items) do
    local sanitized = _sanitize_repo(repo, i)
    local line = _build_repo_line(sanitized)
    M.repositories.list[i] = line
  end

  _validate_repo_list()
end


---Returns the cached JSON response
---@return RepositoryResponse
function M.get()
  return M.repositories
end


---Returns a repository by its name
---@param repo_name string Repository name to search for
---@return Repository|nil
function M.get_by_name(repo_name)
  for _, repo in ipairs(M.repositories.items or {}) do
    if repo.name == repo_name then
      return repo
    end
  end
  return nil
end


---Returns the list of the actual repositories or table with empty string if thte list is empty
---@return string[]
function M.get_list()
  local list = M.repositories.list

  if #list == 0 then
    list = { "" }
  end

  return list
end


---Retrieves the currently selected repository based on the list entry.
---@return Repository|nil
function M.get_selected()
  local json_data = M.get()
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
  local line_count = nvim_buf_line_count(ui_state.buffers.list)
  if selected_line > line_count then
    notify(string.format("[reposcope] Selected line (%d) exceeds list buffer line count (%d)", selected_line, line_count), 3)
    return nil
  end

  -- Read the repository entry in the list (format: "username/reponame: description")
  local line_text = nvim_buf_get_lines(ui_state.buffers.list, selected_line - 1, selected_line, false)[1]
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


--- Clears the repository cache 
---@return nil
function M.clear()
  for k in pairs(M.repositories.items) do M.repositories.items[k] = nil end
  for k in pairs(M.repositories.list) do M.repositories.list[k] = nil end
  M.repositories.total_count = 0
  notify("[reposcope] Repository state cleared.", 2)
end

return M
