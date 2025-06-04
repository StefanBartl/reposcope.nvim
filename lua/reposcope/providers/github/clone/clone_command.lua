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
    return string.format("gh repo clone %s %s", repo_url, output_dir)
  elseif clone_type == "curl" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    return string.format("curl -L -o %s.zip %s", output_dir, zip_url)
  elseif clone_type == "wget" then
    local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")
    return string.format("wget -O %s.zip %s", output_dir, zip_url)
  else
    return string.format("git clone %s %s", repo_url, output_dir)
  end
end

return M
