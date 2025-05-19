---DEBUG:
---hardening
---Annotation

---@desc forward decalarations
local get_clone_informations

local M = {}

local config = require("reposcope.config")
local metrics = require("reposcope.utils.metrics")
local protection = require("reposcope.utils.protection")

function M.init()
  local clone_dir = config.get_clone_dir()
  vim.ui.input({
    prompt = "Set clone path: ",
    default = clone_dir,
    completion = "file",
  }, function(input)
    if (input) then
      M.clone_repository(input)
    else
      print("No input, canceled cloning")
    end
  end)
end

---@class CloneInfo
---@field name string The name of the repository
---@field url string The URL of the repository

---Retrieves clone information for the selected repository
---@private
---@return CloneInfo|nil clone_info The directory, name, and URL of the repository for cloning
function get_clone_informations()
  local repo = require("reposcope.state.repositories.repositories_state").get_selected_repo()
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

--- Clones a GitHub repository using various methods (gh, curl, wget, git)
---@param path string The local path where the repository should be cloned
function M.clone_repository(path)
  if not path or not vim.fn.isdirectory(path) then
    vim.notify("[reposcope] Error cloning: invalid path", 4)
    return
  end

  local clone_type = config.options.clone.type
  local infos = get_clone_informations()
  if not infos then
    vim.notify("[reposcope] Cloning aborted", 4)
    return
  end

  local repo_name = infos.name
  local repo_url = infos.url
  local uuid = metrics.generate_uuid()
  local start_time = vim.loop.hrtime()
  local source = "clone_repo"
  local query = repo_name

  -- Normalize the path (remove trailing slashes and add one)
  path = path:gsub("/+$", "") .. "/"
  local output_dir = vim.fn.fnameescape(path .. repo_name)

  if not vim.fn.isdirectory(output_dir) then
    vim.fn.mkdir(output_dir, "p")
  end

  local success = false
  local output, error_msg = "", ""

  -- Clone based on selected method
  if clone_type == "gh" then
    success, output = protection.safe_execute_shell(string.format("gh repo clone %s %s", repo_url, output_dir))
    error_msg = "GitHub CLI clone failed: " .. (output or "")
  elseif clone_type == "curl" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    success, output = protection.safe_execute_shell(string.format("curl -L -o %s %s", output_zip, zip_url))
    error_msg = "Curl download failed: " .. (output or "")
  elseif clone_type == "wget" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    local output_zip = output_dir .. ".zip"
    success, output = protection.safe_execute_shell(string.format("wget -O %s %s", output_zip, zip_url))
    error_msg = "Wget download failed: " .. (output or "")
  else
    success, output = protection.safe_execute_shell(string.format("git clone %s %s", repo_url, output_dir))
    error_msg = "Git clone failed: " .. (output or "")
  end
  local duration_ms = (vim.loop.hrtime() - start_time) / 1e6 -- Duration in milliseconds

  if success then
    if metrics.record_metrics() then
      metrics.increase_success(uuid, query, source, "clone_repository", duration_ms, 200)
    end
    vim.notify("Repository cloned to: " .. output_dir, 2)
    print("Repository cloned to: " .. output_dir)
  else
    error_msg = string.format("Failed to clone repository: %s", error_msg)
    if metrics.record_metrics() then
      metrics.increase_failed(uuid, query, source, "clone_repository", duration_ms, 500, error_msg)
    end
    vim.notify(error_msg, 4)
    print(error_msg)
  end
end

return M
