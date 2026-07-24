---@module 'reposcope.providers.codeberg.clone.clone_command'
---@brief Builds clone commands (argv tables) for different clone tools, Codeberg-specific.
---@description
--- Generates the correct argv command to clone a Codeberg repository, based
--- on the configured tool (gh is not supported for Codeberg; git/curl/wget
--- are). Codeberg's (Gitea) archive download convention is
--- `/<owner>/<repo>/archive/<branch>.zip`.

---@class CodebergCloneCommandBuilder : CloneCommandBuilderModule
local M = {}


---Creates the appropriate argv command for cloning
---@param clone_type string
---@param repo_url string The repository's clone URL (e.g. `https://codeberg.org/owner/repo.git`)
---@param output_dir string
---@return string[]
function M.build_command(clone_type, repo_url, output_dir)
  local branch = "main"

  if clone_type == "curl" or clone_type == "wget" then
    local base = repo_url:gsub("%.git$", "")
    local zip_url = base .. "/archive/" .. branch .. ".zip"

    if clone_type == "curl" then
      return { "curl", "-L", "-o", output_dir .. ".zip", zip_url }
    else
      return { "wget", "-O", output_dir .. ".zip", zip_url }
    end
  end

  return { "git", "clone", repo_url, output_dir }
end

return M
