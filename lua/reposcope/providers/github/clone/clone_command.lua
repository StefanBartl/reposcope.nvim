---@module 'reposcope.providers.github.clone.clone_command'
---@brief Builds clone shell commands for different clone tools.
---@description
--- This module generates the correct shell command to clone a repository,
--- based on the configured tool (gh, curl, wget, git). It supports both
--- zip-based and git-based cloning.

---@class GithubCloneCommandBuilder : GithubCloneCommandBuilderModule
local M = {}


---Creates the appropriate shell command for cloning
---@param clone_type string
---@param repo_url string
---@param output_dir string
---@return string
function M.build_command(clone_type, repo_url, output_dir)
  if clone_type == "gh" then
    return "gh repo clone " .. repo_url .. " " .. output_dir
  end

  local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")

  if clone_type == "curl" then
    return "curl -L -o " .. output_dir .. ".zip " .. zip_url
  elseif clone_type == "wget" then
    return "wget -O " .. output_dir .. ".zip " .. zip_url
  else
    return "git clone " .. repo_url .. " " .. output_dir
  end
end

return M
