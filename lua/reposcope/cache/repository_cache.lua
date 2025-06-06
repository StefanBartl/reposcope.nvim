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
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
-- State Management
local ui_state = require("reposcope.state.ui.ui_state")
local list_window = require("reposcope.ui.list.list_window")
-- Debugging & Utility
local is_dev_mode = require("reposcope.utils.debug").is_dev_mode
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
    notify("[reposcope] Repository " .. index .. " missing valid 'name', inserted fallback", 2)
    name = "No name"
  end

  ---@type string
  local owner = ensure_string(repo.owner and repo.owner.login)
  if owner == "" then
    notify("[reposcope] Repository " .. index .. " missing valid 'owner.login', inserted fallback", 2)
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
  local parts = {}
  parts[#parts + 1] = repo.owner.login
  parts[#parts + 1] = "/"
  parts[#parts + 1] = repo.name
  parts[#parts + 1] = ": "
  parts[#parts + 1] = repo.description
  return table.concat(parts)
end


---@private
---@return nil
local function _validate_repo_list()
  local list = M.repositories.list
  local inspect = vim.inspect
  local log = notify

  for i = 1, #list do
    local line = list[i]
    if type(line) ~= "string" then
      log("[reposcope] [dev] Repo list line " .. i .. " is not a string: " .. type(line), 4)
      log(inspect(line), 4)
    end
  end
end


---Stores the JSON response of repositories, sanitizes each repo entry and builds lines
---@param json RepositoryResponse
---@return nil
function M.set(json)
  local sanitize = _sanitize_repo
  local build = _build_repo_line
  local items = json.items or {}
  local n = #items
  local list = { [n] = "" }

  for i = 1, n do
    local repo = sanitize(items[i], i)
    list[i] = build(repo)
  end

  M.repositories.total_count = json.total_count or 0
  M.repositories.items = items
  M.repositories.list = list

  if is_dev_mode() then _validate_repo_list() end
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
  local items = M.repositories.items
  if type(items) ~= "table" then return nil end

  for i = 1, #items do
    local repo = items[i]
    if repo.name == repo_name then
      return repo
    end
  end

  notify("[reposcope] Repository not found: " .. repo_name, 3)
  return nil
end

---Returns the list of the actual repositories or table with empty string if the list is empty
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
  local data = M.get()
  local items = data and data.items
  if type(items) ~= "table" or #items == 0 then return nil end

  local selected = list_window.highlighted_line
  if not selected then
    notify("[reposcope] No list item is currently selected.", 3)
    return nil
  end

  local list_buf = ui_state.buffers.list
  if type(list_buf) ~= "number" or not nvim_buf_is_valid(list_buf) then
    notify("[reposcope] List buffer invalid or missing", 3)
    return nil
  end

  -- Avoid accessing a row that does not yet exist
  if selected > nvim_buf_line_count(list_buf) then
    local line_count = nvim_buf_line_count(list_buf)
    notify("[reposcope] Selected line " .. selected .. " exceeds buffer line count " .. line_count, 3)
    selected = 1
    return nil
  end

  -- Read the repository entry in the list (format: "username/reponame: description")
  local line = nvim_buf_get_lines(list_buf, selected - 1, selected, false)[1]
  if type(line) ~= "string" or line == "" then
    notify("[reposcope] No content at selected line " .. selected, 3)
    return nil
  end

  -- Expected format: "username/reponame: description"
  local owner, repo_name = line:match("([^/]+)/([^:]+)")
  if not owner or not repo_name then
    notify("[reposcope] Invalid list line format: " .. line, 4)
    return nil
  end

  for i = 1, #items do
    local repo = items[i]
    if repo.name == repo_name and repo.owner and repo.owner.login == owner then
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
