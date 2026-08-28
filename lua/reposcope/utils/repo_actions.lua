---@module 'reposcope.utils.repo_actions'
---@brief Single-repository git push/pull/fetch.
---@description
--- Companion to `repo_status` (read-only) and `repo_updater` (directory-wide
--- fetch+pull sweep): this module runs mutating git commands against exactly
--- one repository, as triggered interactively (e.g. a keymap on the row under
--- the cursor in `:Reposcope status`) rather than a bulk update. Each action
--- reports success/failure via callback; the caller decides how to surface it
--- (notify, refresh a view, ...).
---
--- Bulk is a caller's concern, not this module's: the status overview's
--- push/pull/fetch/update over a set of marked repositories is a queue over
--- these same single-repository calls, so there is one definition of what
--- "push" means and it does not drift between the single row and the batch.

---@class RepoActions : RepoActionsModule
local M = {}

---@private
---@internal
---Runs `git <cmd...>` in `repo` and normalizes the result to `on_done`.
---@param repo string Absolute path to the repository
---@param cmd string[] Arguments passed to `git` (without the leading "git")
---@param on_done fun(ok: boolean, err: string|nil): nil
---@return nil
local function run_git(repo, cmd, on_done)
  local args = { "git" }
  vim.list_extend(args, cmd)
  vim.system(args, { cwd = repo, text = true }, function(res)
    if res.code ~= 0 then
      on_done(false, (res.stderr ~= "" and res.stderr) or ("git " .. cmd[1] .. " failed"))
      return
    end
    on_done(true, nil)
  end)
end

---Pushes the current branch of `repo` to its upstream.
---@param repo string Absolute path to the repository
---@param on_done fun(ok: boolean, err: string|nil): nil
---@return nil
function M.push(repo, on_done) run_git(repo, { "push" }, on_done) end

---Pulls the current branch of `repo` from its upstream (fast-forward only).
---@param repo string Absolute path to the repository
---@param on_done fun(ok: boolean, err: string|nil): nil
---@return nil
function M.pull(repo, on_done) run_git(repo, { "pull", "--ff-only" }, on_done) end

---Fetches `repo`'s remote-tracking refs (does not change the working tree).
---@param repo string Absolute path to the repository
---@param on_done fun(ok: boolean, err: string|nil): nil
---@return nil
function M.fetch(repo, on_done) run_git(repo, { "fetch", "--prune" }, on_done) end

---Fetches every remote of `repo` and then fast-forwards the current branch.
---
---The same pair `:Reposcope update` runs across a whole directory, expressed
---for a single repository so that `repo_updater` and the status overview's
---bulk update act on exactly the same two commands instead of each spelling
---them out.
---@param repo string Absolute path to the repository
---@param on_done fun(ok: boolean, err: string|nil): nil
---@return nil
function M.update(repo, on_done)
  run_git(repo, { "fetch", "--all", "--prune" }, function(ok, err)
    if not ok then
      on_done(false, err)
      return
    end
    run_git(repo, { "pull", "--ff-only" }, on_done)
  end)
end

return M
