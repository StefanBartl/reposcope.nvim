-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/repos_util_spec.lua — the repository-maintenance stack behind
-- `:Reposcope update` and `:Reposcope status`: discovery (`utils.repos`),
-- the single-repository git actions, the directory-wide update queue, and the
-- status reader.
--
-- Discovery runs against a real fixture tree (handmade `.git` entries, no
-- actual repositories). Everything that would run `git` goes through
-- `vim.system`, which is replaced for the duration -- these modules call it
-- by name at call time rather than binding it, so no reload is needed there.

return function(H)
  local dir, cleanup = H.fixture("repos_util")

  ---Replaces `vim.system` with a scripted responder for the duration of `fn`.
  ---@param respond fun(cmd: string[], opts: table): table  the `res` a real call would deliver
  ---@param fn fun(calls: table[]): nil
  local function with_git(respond, fn)
    local calls = {}
    local original = vim.system
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.system = function(cmd, opts, on_exit)
      calls[#calls + 1] = { cmd = cmd, opts = opts }
      local res = respond(cmd, opts)
      if on_exit then on_exit(res) end
      return { wait = function() return res end, kill = function() end }
    end
    local ok, err = pcall(fn, calls)
    vim.system = original
    if not ok then error(err, 0) end
  end

  local ok_all, err_all = pcall(function()
    ---------------------------------------------------------------------------
    -- utils.repos: what counts as a repository, and where to look
    ---------------------------------------------------------------------------
    do
      local repos = require("reposcope.utils.repos")

      -- A normal clone has a `.git` directory; a worktree or submodule has a
      -- `.git` *file* pointing elsewhere. Both are repositories.
      vim.fn.mkdir(dir .. "/normal/.git", "p")
      vim.fn.mkdir(dir .. "/worktree", "p")
      vim.fn.writefile({ "gitdir: ../normal/.git/worktrees/w" }, dir .. "/worktree/.git")
      vim.fn.mkdir(dir .. "/not-a-repo", "p")
      vim.fn.mkdir(dir .. "/nested/inner/.git", "p")
      vim.fn.writefile({ "loose" }, dir .. "/loose-file.txt")

      H.ok(repos.is_git_repo(dir .. "/normal"), "a `.git` directory makes a repository")
      H.ok(repos.is_git_repo(dir .. "/worktree"), "and so does a `.git` file -- worktrees and submodules count")
      H.falsy(repos.is_git_repo(dir .. "/not-a-repo"), "a plain directory does not")
      H.falsy(repos.is_git_repo(dir .. "/does-not-exist"), "nor does a path that is not there at all")

      local found = repos.collect_repos(dir)
      table.sort(found)
      H.eq(#found, 2, "only the immediate children are scanned -- discovery is deliberately not recursive")
      H.contains(table.concat(found, "|"), "/normal", "the normal clone is found")
      H.contains(table.concat(found, "|"), "/worktree", "and the worktree")
      H.excludes(table.concat(found, "|"), "/nested/inner", "but not a repository one level deeper")

      H.eq(
        #repos.collect_repos(dir .. "/does-not-exist"),
        0,
        "an unreadable directory yields no repositories, silently"
      )
      H.eq(#repos.collect_repos(dir .. "/not-a-repo"), 0, "and an empty one yields none")

      -- Resolution precedence: explicit override, then the configured clone
      -- directory, then nothing.
      local config = require("reposcope.config")
      local saved = config.options.clone.std_dir

      H.eq(
        repos.resolve_base_dir(dir),
        vim.fn.fnamemodify(dir, ":p"):gsub("[\\/]+$", ""),
        "an override is used as given"
      )
      H.excludes(repos.resolve_base_dir(dir .. "/"), "//", "a trailing separator is stripped, not doubled")
      -- Windows spells the same path with backslashes, and `:p` appends one --
      -- both have to be stripped, or every joined path would carry a double
      -- separator.
      local win_style = repos.resolve_base_dir(dir:gsub("/", "\\"))
      H.falsy(win_style:match("[\\/]$"), "a backslash-spelled path is stripped too")

      config.options.clone.std_dir = dir
      H.contains(
        repos.resolve_base_dir(nil),
        "repos_util",
        "without an override the configured clone directory is used"
      )
      H.contains(repos.resolve_base_dir(""), "repos_util", "an empty override counts as no override")

      config.options.clone.std_dir = ""
      H.eq(repos.resolve_base_dir(nil), nil, "with neither, there is nothing to resolve")

      config.options.clone.std_dir = saved
    end

    ---------------------------------------------------------------------------
    -- repo_actions: one repository, one git command
    ---------------------------------------------------------------------------
    do
      local actions = require("reposcope.utils.repo_actions")

      with_git(function() return { code = 0, stdout = "", stderr = "" } end, function(calls)
        local results = {}
        actions.push(dir .. "/normal", function(ok, err) results.push = { ok = ok, err = err } end)
        actions.pull(dir .. "/normal", function(ok, err) results.pull = { ok = ok, err = err } end)
        actions.fetch(dir .. "/normal", function(ok, err) results.fetch = { ok = ok, err = err } end)

        H.eq(table.concat(calls[1].cmd, " "), "git push", "push is a plain `git push`")
        -- `--ff-only` is not optional: a pull that could create a merge commit
        -- in someone's clone without them asking is the thing to avoid here.
        H.eq(table.concat(calls[2].cmd, " "), "git pull --ff-only", "pull refuses anything but a fast-forward")
        H.eq(table.concat(calls[3].cmd, " "), "git fetch --prune", "fetch prunes gone remote branches")
        H.eq(calls[1].opts.cwd, dir .. "/normal", "every command runs in the repository")
        H.ok(calls[1].opts.text, "with text output, so stderr can be reported verbatim")

        H.ok(results.push.ok, "a zero exit is a success")
        H.eq(results.push.err, nil, "with no error")
      end)

      with_git(function() return { code = 1, stdout = "", stderr = "fatal: no upstream" } end, function()
        local got
        actions.push(dir .. "/normal", function(ok, err) got = { ok = ok, err = err } end)
        H.falsy(got.ok, "a non-zero exit is a failure")
        H.eq(got.err, "fatal: no upstream", "carrying git's own stderr")
      end)

      with_git(function() return { code = 1, stdout = "", stderr = "" } end, function()
        local got
        actions.fetch(dir .. "/normal", function(ok, err) got = { ok = ok, err = err } end)
        H.eq(got.err, "git fetch failed", "a silent failure still produces a message naming the command")
      end)

      -- `update` is fetch-then-pull, and the pull must not run if the fetch
      -- failed -- that is the whole reason it is one function.
      with_git(function() return { code = 0, stdout = "", stderr = "" } end, function(calls)
        local got
        actions.update(dir .. "/normal", function(ok) got = ok end)
        H.eq(#calls, 2, "update is two commands")
        H.eq(table.concat(calls[1].cmd, " "), "git fetch --all --prune", "fetch every remote first")
        H.eq(table.concat(calls[2].cmd, " "), "git pull --ff-only", "then fast-forward")
        H.ok(got, "and report success once both have run")
      end)

      with_git(
        function(cmd) return { code = cmd[2] == "fetch" and 1 or 0, stdout = "", stderr = "network is down" } end,
        function(calls)
          local got
          actions.update(dir .. "/normal", function(ok, err) got = { ok = ok, err = err } end)
          H.eq(#calls, 1, "a failed fetch stops before the pull")
          H.falsy(got.ok, "and the failure is reported")
          H.eq(got.err, "network is down", "with the reason")
        end
      )
    end

    ---------------------------------------------------------------------------
    -- repo_updater: the directory-wide queue
    ---------------------------------------------------------------------------
    do
      ---@param env table
      ---@param fn fun(updater: table, env: table): nil
      local function with_updater(env, fn)
        env.updated = {}
        env.notes = {}
        env.progress = {}

        H.with_stubs({
          ["reposcope.utils.checks"] = {
            has_binary = function() return env.has_git ~= false end,
            first_available = function() return nil end,
            resolve_request_tool = function() end,
          },
          ["reposcope.utils.repo_actions"] = {
            update = function(repo, on_done)
              env.updated[#env.updated + 1] = repo
              local fail = env.fail_for and env.fail_for[vim.fn.fnamemodify(repo, ":t")]
              if fail then
                on_done(false, fail)
              else
                on_done(true, nil)
              end
            end,
          },
          ["reposcope.utils.progress"] = {
            create = function(text, total)
              env.progress[#env.progress + 1] = { kind = "create", text = text, total = total }
              return {
                update = function(_, payload) env.progress[#env.progress + 1] = { kind = "update", payload = payload } end,
                finish = function(_, summary) env.progress[#env.progress + 1] = { kind = "finish", text = summary } end,
                on_cancel = function(_, cb) env.cancel = cb end,
              }
            end,
          },
          ["reposcope.utils.debug"] = {
            notify = function(msg) env.notes[#env.notes + 1] = msg end,
            is_dev_mode = function() return false end,
            debugf = function() end,
            options = { dev_mode = false },
          },
        }, { "reposcope.utils.repo_updater" }, function() fn(require("reposcope.utils.repo_updater"), env) end)
      end

      with_updater({ has_git = false }, function(updater, env)
        local completed = false
        updater.update_all(dir, function() completed = true end)
        H.falsy(completed, "without git, on_complete is never called")
        H.contains(env.notes[1], "'git' is not available", "and the reason is reported")
      end)

      with_updater({}, function(updater, env)
        local config = require("reposcope.config")
        local saved = config.options.clone.std_dir
        config.options.clone.std_dir = ""
        local completed = false
        updater.update_all(nil, function() completed = true end)
        H.falsy(completed, "with no directory to work on, on_complete is never called")
        H.contains(env.notes[1], "clone.std_dir is not set", "and the reason is reported")
        config.options.clone.std_dir = saved
      end)

      with_updater({}, function(updater, env)
        local completed = false
        updater.update_all(dir .. "/loose-file.txt", function() completed = true end)
        H.falsy(completed, "a path that is a file, not a directory, aborts early")
        H.contains(env.notes[1], "not accessible", "and says so")
      end)

      with_updater({}, function(updater, env)
        local completed = false
        updater.update_all(dir .. "/not-a-repo", function() completed = true end)
        H.falsy(completed, "a directory with no repositories in it aborts early")
        H.contains(env.notes[1], "No git repositories found", "and says so")
      end)

      with_updater({}, function(updater, env)
        local result
        updater.update_all(dir, function(updated, errors) result = { updated = updated, errors = errors } end)
        vim.wait(500, function() return result ~= nil end)

        H.eq(#env.updated, 2, "every discovered repository is updated")
        H.eq(result.updated, 2, "and counted")
        H.eq(#result.errors, 0, "with no errors")
        H.eq(env.progress[1].kind, "create", "a progress indicator is started")
        H.eq(env.progress[1].total, 2, "with the repository count as the total")
        -- Named before the call, not after: the indicator should say what is
        -- being fetched right now, not what finished last.
        H.eq(env.progress[2].payload.current, 0, "the first update is announced before the first repository runs")
        H.eq(env.progress[#env.progress].kind, "finish", "and the indicator is closed at the end")
        H.contains(env.progress[#env.progress].text, "updated 2 of 2", "reporting the real count")
      end)

      with_updater({ fail_for = { normal = "fatal: could not read from remote" } }, function(updater, env)
        local result
        updater.update_all(dir, function(updated, errors) result = { updated = updated, errors = errors } end)
        vim.wait(500, function() return result ~= nil end)

        H.eq(result.updated, 1, "a repository that failed is not counted as updated")
        H.eq(#result.errors, 1, "but its failure is collected")
        H.contains(result.errors[1], "normal:", "labelled with the repository's own name, not its whole path")
        H.contains(result.errors[1], "could not read from remote", "and carrying git's message")
        H.eq(#env.updated, 2, "the queue continues past a failure rather than stopping")
      end)
    end

    ---------------------------------------------------------------------------
    -- repo_status: reading, parsing and aggregating
    ---------------------------------------------------------------------------
    do
      ---@param env table
      ---@param fn fun(status: table, env: table): nil
      local function with_status(env, fn)
        env.notes = {}
        env.progress = {}

        H.with_stubs({
          ["reposcope.utils.checks"] = {
            has_binary = function() return env.has_git ~= false end,
            first_available = function() return nil end,
            resolve_request_tool = function() end,
          },
          ["reposcope.utils.progress"] = {
            create = function(text, total)
              env.progress[#env.progress + 1] = { kind = "create", text = text, total = total }
              return {
                update = function(_, payload) env.progress[#env.progress + 1] = { kind = "update", payload = payload } end,
                finish = function(_, t) env.progress[#env.progress + 1] = { kind = "finish", text = t } end,
                on_cancel = function() end,
              }
            end,
          },
          ["reposcope.utils.debug"] = {
            notify = function(msg) env.notes[#env.notes + 1] = msg end,
            is_dev_mode = function() return false end,
            debugf = function() end,
            options = { dev_mode = false },
          },
        }, { "reposcope.utils.repo_status" }, function() fn(require("reposcope.utils.repo_status"), env) end)
      end

      local function porcelain(branch, ab, upstream, entries)
        local lines = { "# branch.oid abc123", "# branch.head " .. branch }
        if upstream then lines[#lines + 1] = "# branch.upstream origin/" .. branch end
        if ab then lines[#lines + 1] = "# branch.ab " .. ab end
        for _, e in ipairs(entries or {}) do
          lines[#lines + 1] = e
        end
        return table.concat(lines, "\n")
      end

      -- A clean, up-to-date repository.
      with_status({}, function(status)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 0, stdout = "1700000000\n", stderr = "" } end
          return { code = 0, stdout = porcelain("main", "+0 -0", true), stderr = "" }
        end, function(calls)
          local record
          status.status_one(dir .. "/normal", function(r) record = r end)

          H.eq(table.concat(calls[1].cmd, " "), "git status --porcelain=v2 --branch", "status is read machine-readably")
          H.eq(calls[1].opts.cwd, dir .. "/normal", "in the repository")
          H.eq(table.concat(calls[2].cmd, " "), "git log -1 --format=%ct", "and HEAD's date is read separately")

          H.eq(record.name, "normal", "the record is labelled with the directory name")
          H.eq(record.path, dir .. "/normal", "and carries the full path")
          H.eq(record.branch, "main", "the branch is parsed")
          H.ok(record.has_upstream, "the upstream is detected")
          H.eq(record.ahead, 0, "with nothing ahead")
          H.eq(record.behind, 0, "and nothing behind")
          H.eq(record.dirty, 0, "a clean tree has no changed entries")
          H.eq(record.state, "clean", "so the summary state is clean")
          H.eq(record.last_commit, 1700000000, "and the commit timestamp is attached")
        end)
      end)

      -- Every derived state, and the precedence between them.
      local cases = {
        { ab = "+0 -0", entries = { "1 .M N... 100644 100644 100644 abc def file.lua" }, state = "dirty", dirty = 1 },
        { ab = "+2 -0", entries = {}, state = "ahead", ahead = 2 },
        { ab = "+0 -3", entries = {}, state = "behind", behind = 3 },
        { ab = "+1 -1", entries = {}, state = "diverged", ahead = 1, behind = 1 },
        -- A dirty tree outranks divergence: it is the thing the user has to
        -- deal with first.
        { ab = "+1 -1", entries = { "? untracked.lua" }, state = "dirty", dirty = 1 },
      }
      for _, case in ipairs(cases) do
        with_status({}, function(status)
          with_git(function(cmd)
            if cmd[2] == "log" then return { code = 0, stdout = "1", stderr = "" } end
            return { code = 0, stdout = porcelain("main", case.ab, true, case.entries), stderr = "" }
          end, function()
            local record
            status.status_one(dir .. "/normal", function(r) record = r end)
            H.eq(record.state, case.state, "the derived state is " .. case.state)
            if case.ahead then H.eq(record.ahead, case.ahead, "with the ahead count") end
            if case.behind then H.eq(record.behind, case.behind, "with the behind count") end
            if case.dirty then H.eq(record.dirty, case.dirty, "with the changed-entry count") end
          end)
        end)
      end

      -- A detached HEAD, a repository with no upstream, and one with no commits.
      with_status({}, function(status)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 128, stdout = "", stderr = "fatal: bad default revision" } end
          return { code = 0, stdout = "# branch.oid abc\n# branch.head (detached)\n", stderr = "" }
        end, function()
          local record
          status.status_one(dir .. "/normal", function(r) record = r end)
          H.eq(record.branch, "(detached)", "a detached HEAD is reported as such")
          H.falsy(record.has_upstream, "with no upstream")
          H.eq(record.last_commit, nil, "and an empty repository has no commit date rather than an error")
        end)
      end)

      with_status({}, function(status)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 0, stdout = "1", stderr = "" } end
          return { code = 128, stdout = "", stderr = "fatal: not a git repository" }
        end, function()
          local record, err
          status.status_one(dir .. "/not-a-repo", function(r, e)
            record = r
            err = e
          end)
          H.eq(record, nil, "a repository that cannot be read yields no record")
          H.eq(err, "fatal: not a git repository", "but does yield git's reason")
        end)
      end)

      -- status_all: validation, discovery and the stable ordering
      with_status({ has_git = false }, function(status, env)
        local called = false
        status.status_all(dir, function() called = true end)
        H.falsy(called, "without git, status_all aborts before reading anything")
        H.contains(env.notes[1], "'git' is not available", "and reports why")
      end)

      with_status({}, function(status, env)
        local called = false
        status.status_all(dir .. "/loose-file.txt", function() called = true end)
        H.falsy(called, "a file instead of a directory aborts")
        H.contains(env.notes[1], "not accessible", "with a reason")
      end)

      with_status({}, function(status, env)
        local called = false
        status.status_all(dir .. "/not-a-repo", function() called = true end)
        H.falsy(called, "a directory with no repositories aborts")
        H.contains(env.notes[1], "No git repositories found", "with a reason")
      end)

      with_status({}, function(status, env)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 0, stdout = "1", stderr = "" } end
          return { code = 0, stdout = porcelain("main", "+0 -0", true), stderr = "" }
        end, function()
          local result
          status.status_all(dir, function(records, errors) result = { records = records, errors = errors } end)
          vim.wait(500, function() return result ~= nil end)

          H.eq(#result.records, 2, "both repositories in the directory are reported")
          H.eq(#result.errors, 0, "with no errors")
          H.eq(env.progress[1].total, 2, "the progress indicator knows the total up front")
          H.eq(env.progress[#env.progress].kind, "finish", "and is closed at the end")

          -- The reads run in parallel, so the result order has to come from
          -- discovery, not from whichever git answered first.
          local names = { result.records[1].name, result.records[2].name }
          table.sort(names)
          H.eq(table.concat(names, ","), "normal,worktree", "and the records cover the discovered repositories")
        end)
      end)

      -- A path that is itself a repository is reported on its own rather than
      -- having its children scanned.
      with_status({}, function(status)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 0, stdout = "1", stderr = "" } end
          return { code = 0, stdout = porcelain("main", "+0 -0", true), stderr = "" }
        end, function()
          local result
          status.status_all(dir .. "/normal", function(records) result = records end)
          vim.wait(500, function() return result ~= nil end)
          H.eq(#result, 1, "a single repository path reports exactly that repository")
          H.eq(result[1].name, "normal", "the one that was asked for")
        end)
      end)

      -- Errored repositories leave gaps that must be compacted away.
      with_status({}, function(status)
        with_git(function(cmd, opts)
          if cmd[2] == "log" then return { code = 0, stdout = "1", stderr = "" } end
          if opts.cwd:find("worktree", 1, true) then return { code = 128, stdout = "", stderr = "broken" } end
          return { code = 0, stdout = porcelain("main", "+0 -0", true), stderr = "" }
        end, function()
          local result
          status.status_all(dir, function(records, errors) result = { records = records, errors = errors } end)
          vim.wait(500, function() return result ~= nil end)
          H.eq(#result.records, 1, "the readable repository is still reported")
          H.eq(result.records[1].name, "normal", "and it is the right one -- the gap is compacted, not left as a hole")
          H.eq(#result.errors, 1, "the unreadable one is collected as an error")
          H.contains(result.errors[1], "worktree:", "labelled by name")
        end)
      end)

      -- status_detail: shown verbatim, so what matters is the shape
      with_status({}, function(status)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 0, stdout = "abc123  Someone  a commit\n", stderr = "" } end
          return { code = 0, stdout = "## main...origin/main\n M file.lua\n?? new.lua\n", stderr = "" }
        end, function(calls)
          local lines
          status.status_detail(dir .. "/normal", function(l) lines = l end)

          H.eq(table.concat(calls[1].cmd, " "), "git status --short --branch", "the detail view uses the short format")
          H.eq(
            table.concat(calls[2].cmd, " "),
            "git log -5 --format=%h  %<(18,trunc)%an  %s",
            "plus the last few commits"
          )

          local joined = table.concat(lines, "\n")
          H.contains(joined, "## main...origin/main", "the branch header is shown")
          H.contains(joined, "M file.lua", "along with each changed entry")
          H.contains(joined, "Recent commits", "then a commits section")
          H.contains(joined, "abc123", "with the log output")
          H.excludes(joined, "working tree clean", "and no 'clean' claim while there are changes")
        end)
      end)

      with_status({}, function(status)
        with_git(function(cmd)
          if cmd[2] == "log" then return { code = 0, stdout = "", stderr = "" } end
          -- `--branch` always prints a `##` line, so an otherwise empty output
          -- is not the same as "no output": the entries are the lines that do
          -- not start with `##`.
          return { code = 0, stdout = "## main\n", stderr = "" }
        end, function()
          local lines
          status.status_detail(dir .. "/normal", function(l) lines = l end)
          local joined = table.concat(lines, "\n")
          H.contains(joined, "working tree clean", "only the branch header means the tree is clean")
          H.contains(joined, "(no commits yet)", "and no log output means there are no commits")
        end)
      end)

      with_status({}, function(status)
        with_git(function() return { code = 128, stdout = "", stderr = "fatal: not a git repository" } end, function()
          local lines
          status.status_detail(dir .. "/not-a-repo", function(l) lines = l end)
          H.contains(
            table.concat(lines, "\n"),
            "error:",
            "a failure still produces lines to show, prefixed as an error"
          )
        end)
      end)
    end
  end)

  cleanup()
  if not ok_all then error(err_all, 0) end
end
