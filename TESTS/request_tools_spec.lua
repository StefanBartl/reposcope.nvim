-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/request_tools_spec.lua — the three low-level request tools
-- (`curl`, `gh`, `wget`).
--
-- Nothing here spawns a process. `lib.nvim.cross.uv.spawn_capture` is the one
-- seam all three go through, and it is replaced in `package.loaded` *before*
-- the module under test is required: each of these binds it to a file-local
-- upvalue at load time, so a late field patch would be ignored. What is
-- asserted is the argv that would have been handed to the OS, plus the whole
-- result-handling fan-out: success, non-zero exit, timeout, metrics.

return function(H)
  ---@return table recorder, table stub
  local function spawn_recorder(result)
    local calls = {}
    local stub = function(argv, opts, on_done)
      calls[#calls + 1] = { argv = argv, opts = opts }
      on_done(result)
    end
    return calls, stub
  end

  local function metrics_recorder(enabled)
    local calls = {}
    return calls,
      {
        record_metrics = function() return enabled end,
        increase_success = function(uuid, _query, source, context, _duration, status, url)
          calls[#calls + 1] =
            { kind = "success", uuid = uuid, source = source, context = context, status = status, url = url }
        end,
        increase_failed = function(uuid, _query, source, context, _duration, status, err, url)
          calls[#calls + 1] =
            { kind = "failed", uuid = uuid, source = source, context = context, status = status, err = err, url = url }
        end,
        increase_cache_hit = function() end,
        increase_fcache_hit = function() end,
      }
  end

  local function env_recorder()
    local calls = {}
    return calls,
      {
        array = function(vars)
          calls[#calls + 1] = vars
          return { "PATH=/stub/bin" }
        end,
      }
  end

  local OK = { ok = true, code = 0, signal = 0, stdout = '{"ok":true}', stderr = "", timed_out = false }
  local ERR = { ok = false, code = 7, signal = 0, stdout = "", stderr = "boom", timed_out = false }
  local TIMED_OUT = { ok = false, code = -1, signal = 0, stdout = "", stderr = "", timed_out = true }

  ---------------------------------------------------------------------------
  -- curl: the plain request
  ---------------------------------------------------------------------------
  do
    local calls, spawn = spawn_recorder(OK)
    local _, metrics = metrics_recorder(false)
    local env_calls, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.curl" }, function()
      local curl = require("reposcope.network.request_tools.curl")

      local got
      curl.request(
        "GET",
        "https://api.github.com/search/repositories?q=x",
        function(body, err) got = { body = body, err = err } end,
        nil,
        false,
        "fetch_repositories",
        "uuid-1"
      )

      H.eq(#calls, 1, "curl spawns exactly once")
      local argv = calls[1].argv
      H.eq(argv[1], "curl", "argv starts at the binary, not a shell")
      H.eq(argv[2], "-s", "silent")
      H.eq(argv[3], "-X", "the method is passed as a flag")
      H.eq(argv[4], "GET", "and it is the caller's method")
      H.eq(argv[5], "https://api.github.com/search/repositories?q=x", "the URL is the last argument, unmodified")
      H.eq(#argv, 5, "no headers means no further arguments")
      H.eq(calls[1].opts.stdin, nil, "and no curl config on stdin")
      H.eq(calls[1].opts.timeout_ms, 20000, "SEC-21's 20s ceiling is actually passed")
      H.eq(calls[1].opts.env[1], "PATH=/stub/bin", "the completed environment is forwarded")
      H.eq(env_calls[1], nil, "curl asks for the environment with no extra variables")

      H.eq(got.body, '{"ok":true}', "a successful run answers with stdout")
      H.eq(got.err, nil, "and no error")
    end)
  end

  ---------------------------------------------------------------------------
  -- curl: a credential never reaches argv
  ---------------------------------------------------------------------------
  do
    local calls, spawn = spawn_recorder(OK)
    local _, metrics = metrics_recorder(false)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.curl" }, function()
      local curl = require("reposcope.network.request_tools.curl")

      curl.request("GET", "https://api.github.com/x", function() end, {
        ["Authorization"] = "Bearer s3cret",
        ["Accept"] = "application/vnd.github+json",
      }, false, "ctx", "uuid-2")

      local argv, opts = calls[1].argv, calls[1].opts
      H.eq(argv[1], "curl", "still curl")
      H.eq(argv[2], "-K", "a config file is read")
      H.eq(argv[3], "-", "from stdin")
      H.has(argv, "Accept: application/vnd.github+json", "an ordinary header still travels in argv")
      H.lacks(argv, "Authorization: Bearer s3cret", "the credential does not")
      H.excludes(table.concat(argv, " "), "s3cret", "the token appears nowhere in the command line")
      H.contains(opts.stdin, 'header = "Authorization: Bearer s3cret"', "it goes into the curl config on stdin")
      H.eq(opts.stdin:sub(-1), "\n", "and the config is newline-terminated, so curl accepts it")
    end)
  end

  ---------------------------------------------------------------------------
  -- curl: GitLab's PRIVATE-TOKEN is a credential too
  ---------------------------------------------------------------------------
  do
    local calls, spawn = spawn_recorder(OK)
    local _, metrics = metrics_recorder(false)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.curl" }, function()
      local curl = require("reposcope.network.request_tools.curl")

      curl.request("GET", "https://gitlab.com/api/v4/projects", function() end, {
        ["PRIVATE-TOKEN"] = "glpat-s3cret",
      }, false, "ctx", "uuid-3")

      -- The `-K -` path exists precisely so that "a process's command line
      -- is readable by any other process on the machine" never holds for a
      -- credential (curl.lua's own comment). `lib.nvim.net.curl`'s
      -- `is_secret_header` now knows `private-token` alongside
      -- `authorization`/`proxy-authorization`/`cookie`, so GitLab's token --
      -- which http_client.lua builds for every authenticated GitLab request
      -- -- goes into the curl config on stdin like any other credential,
      -- same as Codeberg's `Authorization: token ...`.
      H.lacks(calls[1].argv, "PRIVATE-TOKEN: glpat-s3cret", "the GitLab token does not reach the command line")
      H.contains(
        calls[1].opts.stdin,
        'header = "PRIVATE-TOKEN: glpat-s3cret"',
        "it goes into the curl config on stdin instead"
      )
    end)
  end

  ---------------------------------------------------------------------------
  -- curl: failure, timeout, metrics
  ---------------------------------------------------------------------------
  do
    local _, spawn = spawn_recorder(ERR)
    local metric_calls, metrics = metrics_recorder(true)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.curl" }, function()
      local curl = require("reposcope.network.request_tools.curl")

      local got
      curl.request(
        "GET",
        "https://api.github.com/x",
        function(body, err) got = { body = body, err = err } end,
        nil,
        true,
        "ctx",
        "uuid-4"
      )

      H.eq(got.body, nil, "a non-zero exit yields no body")
      H.eq(got.err, "curl request failed (code 7)", "and names the exit code")
      H.eq(#metric_calls, 1, "one metric recorded")
      H.eq(metric_calls[1].kind, "failed", "as a failure")
      H.eq(metric_calls[1].source, "curl", "tagged with the tool")
      H.eq(metric_calls[1].uuid, "uuid-4", "and the request's UUID")
      H.eq(metric_calls[1].status, 7, "the process exit code is logged as the status")
    end)
  end

  do
    local _, spawn = spawn_recorder(TIMED_OUT)
    local metric_calls, metrics = metrics_recorder(true)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.curl" }, function()
      local curl = require("reposcope.network.request_tools.curl")

      local got
      curl.request("GET", "https://api.github.com/x", function(body, err) got = { body = body, err = err } end)

      H.eq(got.err, "curl request timed out after 20000ms", "a timeout is reported as one, not as an exit code")
      H.eq(metric_calls[1].kind, "failed", "and still counts as a failed request")
      H.eq(metric_calls[1].uuid, "n/a", "an omitted UUID falls back to 'n/a' rather than crashing the logger")
      H.eq(metric_calls[1].context, "unspecified", "as does an omitted context")
    end)
  end

  -- Metrics are opt-in: with `record_metrics()` false nothing is recorded at all.
  do
    local _, spawn = spawn_recorder(OK)
    local metric_calls, metrics = metrics_recorder(false)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.curl" }, function()
      require("reposcope.network.request_tools.curl").request("GET", "https://x", function() end)
      H.eq(#metric_calls, 0, "metrics off means not a single log entry")
    end)
  end

  ---------------------------------------------------------------------------
  -- gh: the API path is relative, the token is layered onto the environment
  ---------------------------------------------------------------------------
  do
    local calls, spawn = spawn_recorder(OK)
    local metric_calls, metrics = metrics_recorder(true)
    local env_calls, env = env_recorder()
    local appended = {}

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
      ["lib.nvim.fs.write.append"] = function(path, line) appended[#appended + 1] = { path = path, line = line } end,
    }, { "reposcope.network.request_tools.gh" }, function()
      local config = require("reposcope.config")
      local original_token = config.options.github_token
      config.options.github_token = "gho_s3cret"

      local gh = require("reposcope.network.request_tools.gh")

      local got
      gh.request(
        "GET",
        "https://api.github.com/repos/o/r/readme?ref=main",
        function(body, err) got = { body = body, err = err } end,
        { ["Accept"] = "application/vnd.github+json", ["Authorization"] = "Bearer gho_s3cret" },
        false,
        "readme_fetch_api",
        "uuid-5"
      )

      local argv = calls[1].argv
      H.eq(argv[1], "gh", "the GitHub CLI is invoked directly")
      H.eq(argv[2], "api", "through its `api` subcommand")
      H.eq(argv[3], "/repos/o/r/readme?ref=main", "with the host stripped -- gh wants a path, not a URL")
      H.eq(argv[4], "--method", "the method is explicit")
      H.eq(argv[5], "GET", "and forwarded")
      H.has(argv, "Accept: application/vnd.github+json", "headers travel as --header pairs")
      H.lacks(argv, "--verbose", "without debug, gh is not asked to be verbose")
      -- SEC-10: a caller-supplied Authorization header never reaches argv --
      -- gh already authenticates via GITHUB_TOKEN in the environment below,
      -- which makes a second, argv-visible copy both redundant and exposed.
      H.lacks(argv, "Authorization: Bearer gho_s3cret", "the credential does not reach the command line")
      H.excludes(table.concat(argv, " "), "gho_s3cret", "the token appears nowhere in argv")
      H.eq(calls[1].opts.timeout_ms, 20000, "the same 20s ceiling applies")
      H.eq(env_calls[1].GITHUB_TOKEN, "gho_s3cret", "the configured token is layered onto the child environment")
      H.eq(#appended, 0, "and nothing is written to the debug log while debugging is off")

      H.eq(got.body, '{"ok":true}', "stdout comes back to the caller")
      H.eq(metric_calls[1].kind, "success", "a success is recorded")
      H.eq(metric_calls[1].status, 200, "as a 200 -- gh's exit code says nothing finer")

      config.options.github_token = original_token
    end)
  end

  -- An empty token must not create a bogus `GITHUB_TOKEN=` entry.
  do
    local _, spawn = spawn_recorder(OK)
    local _, metrics = metrics_recorder(false)
    local env_calls, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.gh" }, function()
      local config = require("reposcope.config")
      local original_token = config.options.github_token
      config.options.github_token = ""

      require("reposcope.network.request_tools.gh").request("GET", "https://api.github.com/x", function() end)
      H.eq(env_calls[1], nil, "no token means no environment override at all")

      config.options.github_token = original_token
    end)
  end

  -- Debug mode adds --verbose and appends one line to the gh debug log.
  do
    local calls, spawn = spawn_recorder(OK)
    local _, metrics = metrics_recorder(false)
    local _, env = env_recorder()
    local appended = {}

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
      ["lib.nvim.fs.write.append"] = function(path, line) appended[#appended + 1] = { path = path, line = line } end,
    }, { "reposcope.network.request_tools.gh" }, function()
      require("reposcope.network.request_tools.gh").request(
        "GET",
        "https://api.github.com/x",
        function() end,
        { ["Authorization"] = "Bearer gho_s3cret" },
        true
      )

      H.has(calls[1].argv, "--verbose", "debug asks gh to be verbose")
      H.eq(#appended, 1, "and writes exactly one line to the debug log")
      H.contains(appended[1].path, "gh-debug.txt", "into the gh debug file")
      H.contains(appended[1].line, "<redacted>", "with the credential redacted")
      H.excludes(appended[1].line, "gho_s3cret", "so the token never lands on disk")
    end)
  end

  do
    local _, spawn = spawn_recorder(TIMED_OUT)
    local _, metrics = metrics_recorder(false)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.gh" }, function()
      local got
      require("reposcope.network.request_tools.gh").request(
        "GET",
        "https://api.github.com/x",
        function(body, err) got = { body = body, err = err } end
      )
      H.eq(got.err, "gh request timed out after 20000ms", "gh reports a timeout through the callback")
    end)
  end

  ---------------------------------------------------------------------------
  -- wget: GET only
  ---------------------------------------------------------------------------
  do
    local calls, spawn = spawn_recorder(OK)
    local metric_calls, metrics = metrics_recorder(true)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.wget" }, function()
      local wget = require("reposcope.network.request_tools.wget")

      -- A method wget cannot express is refused before anything is spawned.
      local refused
      wget.request("POST", "https://x", function(body, err) refused = { body = body, err = err } end)
      H.eq(#calls, 0, "a POST never reaches the process layer")
      H.eq(refused.err, "wget only supports GET method", "and says why")

      local got
      wget.request(
        "GET",
        "https://raw.githubusercontent.com/o/r/main/README.md",
        function(body, err) got = { body = body, err = err } end,
        { ["Authorization"] = "Bearer ignored" },
        false,
        "readme_fetch_raw",
        "uuid-6"
      )

      local argv = calls[1].argv
      H.eq(argv[1], "wget", "wget is invoked directly")
      H.eq(argv[2], "--quiet", "quietly")
      H.eq(argv[3], "--output-document=-", "writing the body to stdout")
      H.eq(argv[4], "https://raw.githubusercontent.com/o/r/main/README.md", "and the URL last")
      H.eq(#argv, 4, "headers are dropped entirely -- wget's parameter is named `_headers` for that reason")
      H.excludes(table.concat(argv, " "), "ignored", "so a token handed to wget is not leaked, it is discarded")
      H.eq(calls[1].opts.timeout_ms, 20000, "same timeout ceiling")

      H.eq(got.body, '{"ok":true}', "the body comes back")
      H.eq(metric_calls[1].source, "wget", "metrics name wget as the source")
    end)
  end

  do
    local _, spawn = spawn_recorder(ERR)
    local _, metrics = metrics_recorder(false)
    local _, env = env_recorder()

    H.with_stubs({
      ["lib.nvim.cross.uv.spawn_capture"] = spawn,
      ["reposcope.utils.metrics"] = metrics,
      ["reposcope.utils.spawn_env"] = env,
    }, { "reposcope.network.request_tools.wget" }, function()
      local got
      require("reposcope.network.request_tools.wget").request(
        "GET",
        "https://x",
        function(body, err) got = { body = body, err = err } end
      )
      H.eq(got.err, "wget request failed (code 7)", "a non-zero wget exit is reported with its code")
    end)
  end
end
