---@module 'reposcope.providers.gitlab.clone.clone_command'
---@brief Builds clone commands (argv tables) for different clone tools, GitLab-specific.
---@description
--- Generates the correct argv command to clone a GitLab repository, based on
--- the configured tool (gh is not supported for GitLab; git/curl/wget are).
--- GitLab's archive download convention differs from GitHub's, so the zip URL
--- is built from GitLab's own `/-/archive/<branch>/<repo>-<branch>.zip` route
--- instead of a generic `.git`-suffix substitution.

---@class GitlabCloneCommandBuilder : CloneCommandBuilderModule
local M = {}


---Creates the appropriate argv command for cloning
---@param clone_type string
---@param repo_url string The repository's clone URL (e.g. `https://gitlab.com/owner/repo.git`)
---@param output_dir string
---@return string[]
function M.build_command(clone_type, repo_url, output_dir)
  -- owner/repo/branch, derived from the .git clone URL
  local owner, repo = repo_url:match("gitlab%.com/(.+)/([^/]+)%.git$")
  repo = repo or repo_url:match("([^/]+)%.git$") or output_dir:match("([^/]+)$")
  local branch = "main"

  if clone_type == "curl" or clone_type == "wget" then
    local zip_url = "https://gitlab.com/" .. (owner and (owner .. "/") or "") .. repo
        .. "/-/archive/" .. branch .. "/" .. repo .. "-" .. branch .. ".zip"

    if clone_type == "curl" then
      return { "curl", "-L", "-o", output_dir .. ".zip", zip_url }
    else
      return { "wget", "-O", output_dir .. ".zip", zip_url }
    end
  end

  return { "git", "clone", repo_url, output_dir }
end

return M
