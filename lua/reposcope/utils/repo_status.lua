---@module 'reposcope.utils.repo_status'
---@brief Collects a compact git status overview for one or many local repositories.
---@description
--- Counterpart to `clone_updater`: where the updater *changes* repositories, this
--- module only *reads* them. For each git repository found in (or equal to) a base
--- directory it runs `git status --porcelain=v2 --branch` and distills the
--- machine-readable output into a small record — current branch, ahead/behind
--- counts relative to the upstream, and the number of uncommitted changes.
---
--- The base directory is resolved exactly like the updater (explicit override >
--- `config.options.clone.std_dir`). If the resolved path is itself a git
--- repository, only that single repository is reported; otherwise its immediate
--- subdirectories are scanned. Status is read-only, so each repository is queried
--- through a non-blocking job and the aggregated records are handed back once all
--- queries finish, preserving the discovery order.
---
--- Live feedback while the repositories are being read goes through
--- `utils.progress` (optional dependency): a single `git status` is fast, but a
--- directory of several dozen clones adds up to a noticeable wait with no output.
---
--- Notifications follow the Reposcope convention (`utils.debug.notify`): progress
--- is dev-mode only, errors are always shown. Rendering of the final overview is
--- delegated to the caller via the `on_complete` callback.

---@class RepoStatusRecord
---@field name string Repository directory name (tail of the path)
---@field path string Absolute path to the repository
---@field branch string Current branch, or "(detached)" when HEAD is detached
---@field ahead integer Commits ahead of the upstream (0 when no upstream)
---@field behind integer Commits behind the upstream (0 when no upstream)
---@field has_upstream boolean Whether the current branch tracks an upstream
---@field dirty integer Number of changed/untracked entries in the working tree
---@field state "clean"|"dirty"|"ahead"|"behind"|"diverged" Derived summary state
---@field last_commit integer|nil Unix timestamp of HEAD's commit date (nil on an empty repo)

---@class ReposcopeRepoStatus
local M = {}

-- Vim Utilities
local fnamemodify = vim.fn.fnamemodify
local uv = vim.uv or vim.loop
-- Utils
local has_binary = require("reposcope.utils.checks").has_binary
local notify = require("reposcope.utils.debug").notify
-- Shared repository discovery helpers
local repos_util = require("reposcope.utils.repos")
local resolve_base_dir = repos_util.resolve_base_dir
local collect_repos = repos_util.collect_repos
local is_git_repo = repos_util.is_git_repo
-- Progress indicator (optional dependency, see utils/progress.lua)
local progress = require("reposcope.utils.progress")

---@private
---@internal
---Derives a single summary state from the parsed status fields.
---Precedence: dirty working tree first, then upstream divergence.
---@param dirty integer Number of changed entries
---@param ahead integer Commits ahead of upstream
---@param behind integer Commits behind upstream
---@return "clean"|"dirty"|"ahead"|"behind"|"diverged"
local function derive_state(dirty, ahead, behind)
  if dirty > 0 then
    return "dirty"
  elseif ahead > 0 and behind > 0 then
    return "diverged"
  elseif ahead > 0 then
    return "ahead"
  elseif behind > 0 then
    return "behind"
  end
  return "clean"
end

---@private
---@internal
---Parses `git status --porcelain=v2 --branch` output into a status record.
---Header lines start with `# branch.*`; every other non-empty line is a changed
---entry, so the working tree is dirty when at least one such line is present.
---@param repo string Absolute path to the repository (used for the display name)
---@param out string Raw stdout from the status command
---@return RepoStatusRecord
local function parse_status(repo, out)
  local branch = "(detached)"
  local ahead, behind = 0, 0
  local has_upstream = false
  local dirty = 0

  for line in (out .. "\n"):gmatch("(.-)\n") do
    if line ~= "" then
      if line:sub(1, 1) == "#" then
        local head = line:match("^# branch%.head (.+)$")
        if head then
          branch = head
        elseif line:match("^# branch%.upstream ") then
          has_upstream = true
        else
          local a, b = line:match("^# branch%.ab %+(%-?%d+) %-(%d+)$")
          if a then
            ahead, behind = tonumber(a) or 0, tonumber(b) or 0
          end
        end
      else
        dirty = dirty + 1
      end
    end
  end

  return {
    name = fnamemodify(repo, ":t"),
    path = repo,
    branch = branch,
    ahead = ahead,
    behind = behind,
    has_upstream = has_upstream,
    dirty = dirty,
    state = derive_state(dirty, ahead, behind),
  }
end

---@private
---@internal
---Reads the commit timestamp of HEAD. Separate from `git status`, which does
---not carry it; an empty repository has no HEAD and yields nil rather than an
---error, since "no commits yet" is a legitimate state for a fresh clone target.
---@param repo string Absolute path to the repository
---@param on_done fun(ts: integer|nil): nil
---@return nil
local function last_commit_ts(repo, on_done)
  vim.system({ "git", "log", "-1", "--format=%ct" }, { cwd = repo, text = true }, function(res)
    if res.code ~= 0 then
      on_done(nil)
      return
    end
    on_done(tonumber(vim.trim(res.stdout or "")))
  end)
end

---@private
---@internal
---Queries the git status of a single repository, plus HEAD's commit date.
---The two git calls are independent, so they run concurrently and the record is
---handed back once both have returned.
---@param repo string Absolute path to the repository
---@param on_done fun(record: RepoStatusRecord|nil, err: string|nil): nil
---@return nil
local function status_repo(repo, on_done)
  ---@type RepoStatusRecord|nil
  local record
  ---@type string|nil
  local err
  local ts
  local got_status, got_ts = false, false

  local function settle()
    if not (got_status and got_ts) then return end
    if record then record.last_commit = ts end
    on_done(record, err)
  end

  vim.system({ "git", "status", "--porcelain=v2", "--branch" }, { cwd = repo, text = true }, function(res)
    if res.code ~= 0 then
      err = (res.stderr ~= "" and res.stderr) or "git status failed"
    else
      record = parse_status(repo, res.stdout or "")
    end
    got_status = true
    settle()
  end)

  last_commit_ts(repo, function(value)
    ts = value
    got_ts = true
    settle()
  end)
end

---Queries the git status of a single repository (no discovery, no progress
---indicator). Used to refresh one row after an interactive push/pull/fetch
---rather than re-reading every repository in the directory.
---@param repo string Absolute path to the repository
---@param on_done fun(record: RepoStatusRecord|nil, err: string|nil): nil
---@return nil
function M.status_one(repo, on_done) status_repo(repo, on_done) end

---Collects a human-readable detail view of one repository: the porcelain
---short status plus the last few commits. Unlike `status_one` this is not
---parsed into a record — it is meant to be shown verbatim, the way `git
---status` would print it.
---@param repo string Absolute path to the repository
---@param on_done fun(lines: string[]): nil Always called, with an error line on failure
---@return nil
function M.status_detail(repo, on_done)
  local short, log
  local function settle()
    if short == nil or log == nil then return end

    -- `--branch` always emits a leading "## <branch>" line, so emptiness of the
    -- raw output is not a usable "is it clean" test: the entry lines are the
    -- ones that don't start with "##".
    local lines, entries = {}, 0
    for line in (short .. "\n"):gmatch("(.-)\n") do
      if line ~= "" then
        lines[#lines + 1] = "  " .. line
        if line:sub(1, 2) ~= "##" then entries = entries + 1 end
      end
    end
    if entries == 0 then lines[#lines + 1] = "  working tree clean" end

    lines[#lines + 1] = ""
    lines[#lines + 1] = " Recent commits"
    if log ~= "" then
      for line in (log .. "\n"):gmatch("(.-)\n") do
        if line ~= "" then lines[#lines + 1] = "  " .. line end
      end
    else
      lines[#lines + 1] = "  (no commits yet)"
    end

    on_done(lines)
  end

  vim.system({ "git", "status", "--short", "--branch" }, { cwd = repo, text = true }, function(res)
    short = (res.code == 0) and vim.trim(res.stdout or "") or ("error: " .. vim.trim(res.stderr or ""))
    settle()
  end)

  vim.system({ "git", "log", "-5", "--format=%h  %<(18,trunc)%an  %s" },
    { cwd = repo, text = true }, function(res)
      log = (res.code == 0) and vim.trim(res.stdout or "") or ""
      settle()
    end)
end

---Collects the git status of every repository in the resolved base directory.
---If the resolved path is itself a repository, only that one is reported.
---Validation failures (missing git, inaccessible directory, no repositories) are
---reported via notification and abort early without invoking `on_complete`.
---@param path string|nil Optional directory or single-repo override (defaults to the clone directory)
---@param on_complete fun(records: RepoStatusRecord[], errors: string[]): nil|nil Called once on completion
---@return nil
function M.status_all(path, on_complete)
  if not has_binary("git") then
    notify("[reposcope] Cannot read repository status: 'git' is not available in PATH", 4)
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

  -- A path that is itself a repository is reported on its own; otherwise scan children.
  local repos = is_git_repo(base_dir) and { base_dir } or collect_repos(base_dir)
  if #repos == 0 then
    notify("[reposcope] No git repositories found in " .. base_dir, 3)
    return
  end

  notify(("[reposcope] Reading status of %d repositories in %s ..."):format(#repos, base_dir), 2)

  -- Indexed by discovery order so the overview stays stable despite async completion.
  ---@type table<integer, RepoStatusRecord>
  local indexed = {}
  ---@type string[]
  local errors = {}
  local total = #repos
  local remaining = total

  -- Countable by completions, not by index: these run in parallel, so "how many
  -- have come back" is the only meaningful number — there is no single repository
  -- that is currently being read.
  local handle = progress.create(("reading status of %d repositories"):format(total), total)

  local function finish()
    remaining = remaining - 1
    if handle then
      handle:update({
        text = ("%d of %d read"):format(total - remaining, total),
        current = total - remaining,
        total = total,
      })
    end
    if remaining > 0 then return end
    if handle then handle:finish(("read %d of %d repositories"):format(total - #errors, total)) end
    -- Compact into a dense, discovery-ordered list (errored repos leave gaps).
    ---@type RepoStatusRecord[]
    local records = {}
    for i = 1, total do
      if indexed[i] then records[#records + 1] = indexed[i] end
    end
    vim.schedule(function()
      if on_complete then on_complete(records, errors) end
    end)
  end

  for i = 1, total do
    local repo = repos[i]
    status_repo(repo, function(record, err)
      if record then
        indexed[i] = record
      else
        errors[#errors + 1] = fnamemodify(repo, ":t") .. ": " .. (err or "unknown error")
      end
      finish()
    end)
  end
end

return M
