---@module 'reposcope.providers.codeberg.clone.clone_command'
---@brief Builds clone commands (argv tables) for different clone tools, Codeberg-specific.
---@description
--- Generates the correct argv command to clone a Codeberg repository, based
--- on the configured tool (gh is not supported for Codeberg; git/curl/wget
--- are). Codeberg's (Gitea) archive download convention is
--- `/<owner>/<repo>/archive/<branch>.zip`.

---@class CodebergCloneCommandBuilder : CloneCommandBuilderModule
local M = {}

-- SEC-21: see the GitHub clone_command's own note -- an archive download can
-- be bounded with a single flag without imposing a byte-limit a real repo
-- archive could legitimately exceed.
local ARCHIVE_TIMEOUT_S = 300

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
      return { "curl", "-L", "--max-time", tostring(ARCHIVE_TIMEOUT_S), "-o", output_dir .. ".zip", zip_url }
    else
      return { "wget", "--timeout=" .. ARCHIVE_TIMEOUT_S, "-O", output_dir .. ".zip", zip_url }
    end
  end

  return { "git", "clone", repo_url, output_dir }
end

return M
