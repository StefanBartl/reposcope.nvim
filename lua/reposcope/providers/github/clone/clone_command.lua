---@module 'reposcope.providers.github.clone.clone_command'
---@brief Builds clone commands (argv tables) for different clone tools.
---@description
--- This module generates the correct command, as an argv table, to clone a
--- repository, based on the configured tool (gh, curl, wget, git). It supports
--- both zip-based and git-based cloning. Using an argv table (rather than a
--- concatenated shell string) avoids shell-quoting pitfalls entirely — paths
--- with spaces or special characters are passed through unescaped and work
--- identically on Windows (cmd.exe) and POSIX shells.

---@class GithubCloneCommandBuilder : CloneCommandBuilderModule
local M = {}

-- SEC-21: an archive download, unlike a `git clone`, has a clean single flag
-- to bound it (`--max-time`/`--timeout=`) without the tool needing to
-- understand progress -- worth setting even though this path runs through
-- run_async_captured, which has no timeout_ms of its own (unlike
-- spawn_capture, used by network/request_tools/*). Generous rather than
-- tight: this downloads a whole repository archive, not a small API
-- response, so no byte-limit is imposed here -- there is no reasonable
-- universal ceiling for "how big can a repo be" the way there is for e.g. a
-- single release binary.
local ARCHIVE_TIMEOUT_S = 300

---Creates the appropriate argv command for cloning
---@param clone_type string
---@param repo_url string
---@param output_dir string
---@return string[]
function M.build_command(clone_type, repo_url, output_dir)
  if clone_type == "gh" then return { "gh", "repo", "clone", repo_url, output_dir } end

  local zip_url = repo_url:gsub("%.git$", "/archive/refs/heads/main.zip")

  if clone_type == "curl" then
    return { "curl", "-L", "--max-time", tostring(ARCHIVE_TIMEOUT_S), "-o", output_dir .. ".zip", zip_url }
  elseif clone_type == "wget" then
    return { "wget", "--timeout=" .. ARCHIVE_TIMEOUT_S, "-O", output_dir .. ".zip", zip_url }
  else
    return { "git", "clone", repo_url, output_dir }
  end
end

return M
