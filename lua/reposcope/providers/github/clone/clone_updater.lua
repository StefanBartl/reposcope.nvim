---@module 'reposcope.providers.github.clone.clone_updater'
---@brief Bulk-updates all cloned git repositories in a directory.
---@description
--- Asynchronously runs `git fetch --all --prune` followed by `git pull --ff-only`
--- for every git repository found directly inside a base directory. Repositories
--- are processed sequentially through a non-blocking job queue, so the editor
--- stays responsive even for large collections. Non-git directories are skipped
--- and errors are collected and reported together at the end.
---
--- The base directory defaults to the configured clone directory
--- (`config.options.clone.std_dir`) — i.e. the place Reposcope clones repositories
--- into — and can be overridden with an explicit path argument. This makes
--- `:Reposcope update` the natural continuation of the clone lifecycle:
--- discover → clone → update.
---
--- Notifications follow the Reposcope convention (`utils.debug.notify`): progress
--- is dev-mode only, errors are always shown. The final, user-facing summary is
--- delegated to the caller via the optional `on_complete` callback.

---@class GithubCloneUpdater : GithubCloneUpdaterModule
local M = {}

-- Vim Utilities
local fnamemodify = vim.fn.fnamemodify
-- Configuration and Utils
local uv = vim.uv or vim.loop
local has_binary = require("reposcope.utils.checks").has_binary
local notify = require("reposcope.utils.debug").notify
-- Shared repository discovery helpers
local repos_util = require("reposcope.utils.repos")
local resolve_base_dir = repos_util.resolve_base_dir
local collect_repos = repos_util.collect_repos


---Runs `git fetch --all --prune` then `git pull --ff-only` for a single repository.
---@param repo string Absolute path to the repository
---@param on_done fun(success: boolean, err: string|nil): nil
---@return nil
local function update_repo(repo, on_done)
  vim.system({ "git", "fetch", "--all", "--prune" }, { cwd = repo, text = true }, function(fetch_res)
    if fetch_res.code ~= 0 then
      on_done(false, (fetch_res.stderr ~= "" and fetch_res.stderr) or "git fetch failed")
      return
    end

    vim.system({ "git", "pull", "--ff-only" }, { cwd = repo, text = true }, function(pull_res)
      if pull_res.code ~= 0 then
        on_done(false, (pull_res.stderr ~= "" and pull_res.stderr) or "git pull failed")
        return
      end

      on_done(true, nil)
    end)
  end)
end

---Updates every git repository found in the resolved base directory.
---Validation failures (missing git, inaccessible directory, no repositories) are
---reported via notification and abort early without invoking `on_complete`.
---@param path string|nil Optional directory override (defaults to the clone directory)
---@param on_complete fun(updated: integer, errors: string[]): nil|nil Called once on completion with the result
---@return nil
function M.update_all(path, on_complete)
  if not has_binary("git") then
    notify("[reposcope] Cannot update repositories: 'git' is not available in PATH", 4)
    return
  end

  local base_dir = resolve_base_dir(path)
  if not base_dir then
    notify("[reposcope] No repository directory provided and clone.std_dir is not set", 4)
    return
  end

  local stat = uv.fs_stat(base_dir)
  if not stat or stat.type ~= "directory" then
    notify("[reposcope] Repository directory is not accessible: " .. base_dir, 4)
    return
  end

  local repos = collect_repos(base_dir)
  if #repos == 0 then
    notify("[reposcope] No git repositories found in " .. base_dir, 3)
    return
  end

  notify(("[reposcope] Updating %d repositories in %s ..."):format(#repos, base_dir), 2)

  ---@type string[]
  local errors = {}
  local updated = 0
  local index = 1

  local function run_next()
    local repo = repos[index]
    if not repo then
      vim.schedule(function()
        if on_complete then
          on_complete(updated, errors)
        end
      end)
      return
    end

    update_repo(repo, function(success, err)
      if success then
        updated = updated + 1
        notify("[reposcope] Updated " .. fnamemodify(repo, ":t"), 2)
      else
        errors[#errors + 1] = fnamemodify(repo, ":t") .. ": " .. (err or "unknown error")
      end

      index = index + 1
      run_next()
    end)
  end

  run_next()
end

return M
