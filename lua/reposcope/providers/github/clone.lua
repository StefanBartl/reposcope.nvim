---@class GithubCloner
---@brief Clones a repository using the preferred clone tool and tracks the request state
---@description
--- This module handles the cloning of a selected GitHub repository. It uses
--- configuration values to determine which clone method (gh, curl, wget, git)
--- to use and reports success/failure via metrics. It uses a UUID to register
--- and track the clone request state via the request_state module.
---@field clone_repository fun(path: string, uuid: string): nil Starts the clone operation
local M = {}

---@description Forward declarations for private functions
local get_clone_informations, build_clone_command, run_clone_with_metrics

-- Debug Utilities
local hrtime = vim.uv.hrtime
local metrics = require("reposcope.utils.metrics")
local request_state = require("reposcope.state.requests_state")
-- Project-Specific Config and Utility Modules
local config = require("reposcope.config")
local protection = require("reposcope.utils.protection")


--- Clones a GitHub repository using various methods (gh, curl, wget, git)
---@param path string The local path where the repository should be cloned
---@param uuid string
function M.clone_repository(path, uuid)
  if not request_state.is_registered(uuid) then return end
  if request_state.is_request_active(uuid) then return end
  request_state.start_request(uuid)

  if not path or not vim.fn.isdirectory(path) then
    vim.notify("[reposcope] Error cloning: invalid path", 4)
    request_state.end_request(uuid)
    return
  end

  local clone_type = config.options.clone.type
  local infos = get_clone_informations()
  if not infos then
    request_state.end_request(uuid)
    return
  end

  local repo_name = infos.name
  local repo_url = infos.url

  -- Normalize the path (remove trailing slashes and add one)
  path = path:gsub("/+$", "") .. "/"
  local output_dir = vim.fn.fnameescape(path .. repo_name)

  if not vim.fn.isdirectory(output_dir) then
    vim.fn.mkdir(output_dir, "p")
  end

  local cmd = build_clone_command(clone_type, repo_url, output_dir)
  run_clone_with_metrics(cmd, uuid, repo_name, "clone_repo")
  request_state.end_request(uuid)
 end


---@class CloneInfo
---@field name string The name of the repository
---@field url string The URL of the repository

---@private
---Retrieves clone information for the selected repository
---@return CloneInfo|nil clone_info The directory, name, and URL of the repository for cloning
function get_clone_informations()
  local repo = require("reposcope.cache.repository_cache").get_selected()
  if not repo then
    vim.notify("[reposcope] Error cloning: Repository is nil", 4)
    return nil
  end

  local repo_name = ""
  if repo.name and repo.name ~= "" then
    repo_name = repo.name
  else
    vim.notify("[reposcope] Error cloning: Repository name is invalid", 4)
    return nil
  end

  local repo_url = ""
  if repo.html_url and repo.html_url ~= "" then
    repo_url = repo.html_url
  else
    vim.notify("[reposcope] Error cloning: Repository url is invalid", 4)
    return nil
  end

  return { name = repo_name, url = repo_url }
end


---@private
---@param clone_type string The configured cloning method ("gh", "curl", "wget", "git")
---@param repo_url string The GitHub repo URL (e.g. https://github.com/user/repo)
---@param output_dir string The directory to clone to
---@return string cmd The shell command to execute
function build_clone_command(clone_type, repo_url, output_dir)
  if clone_type == "gh" then
    return string.format("gh repo clone %s %s", repo_url, output_dir)
  elseif clone_type == "curl" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    return string.format("curl -L -o %s %s", output_zip, zip_url)
  elseif clone_type == "wget" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    return string.format("wget -O %s %s", output_zip, zip_url)
  else -- fallback to plain git
    return string.format("git clone %s %s", repo_url, output_dir)
  end
end


---@private
---@param cmd string The shell command to execute
---@param uuid string UUID for metrics tracking
---@param repo_name string The repository name (used for logging)
---@param source string The metrics source (e.g., "clone_repo")
---@return nil
function run_clone_with_metrics(cmd, uuid, repo_name, source)
  local start = hrtime()
  local success, output = protection.safe_execute_shell(cmd)
  local duration_ms = (hrtime() - start) / 1e6

  if success then
    if metrics.record_metrics() then
      metrics.increase_success(uuid, repo_name, source, "clone_repo", duration_ms, 200)
    end
    vim.notify("Repository cloned successfully", 2)
  else
    local err_msg = "Clone failed: " .. (output or "unknown error")
    if metrics.record_metrics() then
      metrics.increase_failed(uuid, repo_name, source, "clone_repo", duration_ms, 500, err_msg)
    end
    vim.notify(err_msg, 4)
  end
end

return M
