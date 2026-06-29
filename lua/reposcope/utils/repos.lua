---@module 'reposcope.utils.repos'
---@brief Shared helpers for discovering local git repositories on disk.
---@description
--- Small, dependency-light utilities used by every command that operates on a
--- directory of cloned repositories (e.g. `:Reposcope update`, `:Reposcope
--- status`). Keeping the scanning logic in one place guarantees that all repo
--- maintenance commands agree on what counts as a repository, how the base
--- directory is resolved, and which subdirectories are considered.
---
--- Resolution precedence for the base directory is: explicit override argument >
--- configured clone directory (`config.options.clone.std_dir`). Scanning is
--- non-recursive — only the immediate children of the base directory are
--- inspected.

---@class ReposcopeReposUtil
local M = {}

-- Vim Utilities
local uv = vim.uv or vim.loop
local fnamemodify = vim.fn.fnamemodify
local expand = vim.fn.expand
-- Configuration
local config = require("reposcope.config")


---Checks whether a directory is a git repository.
---Accepts both a `.git` directory (normal clone) and a `.git` file (worktree/submodule).
---@param path string Absolute path to the candidate directory
---@return boolean
function M.is_git_repo(path)
  local stat = uv.fs_stat(path .. "/.git")
  return stat ~= nil and (stat.type == "directory" or stat.type == "file")
end

---Resolves the base directory whose immediate subdirectories are scanned for repos.
---Precedence: explicit override > configured clone directory (`clone.std_dir`).
---@param override string|nil Explicit directory passed on the command line
---@return string|nil base_dir Expanded path without trailing separator, or nil if unresolved
function M.resolve_base_dir(override)
  local dir = override

  if not dir or dir == "" then
    dir = config.options.clone and config.options.clone.std_dir or nil
  end

  if not dir or dir == "" then
    return nil
  end

  return fnamemodify(expand(dir), ":p"):gsub("[\\/]+$", "")
end

---Collects all immediate subdirectories of `base_dir` that are git repositories.
---@param base_dir string Absolute path to scan (without trailing separator)
---@return string[] repos Absolute paths of discovered repositories
function M.collect_repos(base_dir)
  ---@type string[]
  local repos = {}

  local handle = uv.fs_scandir(base_dir)
  if not handle then
    return repos
  end

  while true do
    local name, typ = uv.fs_scandir_next(handle)
    if not name then
      break
    end

    if typ == "directory" then
      local path = base_dir .. "/" .. name
      if M.is_git_repo(path) then
        repos[#repos + 1] = path
      end
    end
  end

  return repos
end

return M
