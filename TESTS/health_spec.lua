-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/health_spec.lua — `:checkhealth reposcope`.
--
-- `vim.health` is replaced with a recorder before `health.lua` is required
-- (it binds the module at load time), and the things it reports on --
-- installed binaries, the configured tool, the token, images.nvim -- are
-- scripted. Nothing here depends on what happens to be installed on the
-- machine running the suite, which is the whole point: a health check whose
-- own test only passes on the author's laptop reports nothing.

return function(H)
  ---@param opts table  { available: table<string,boolean>, request_tool: string, token: boolean, images: table|false }
  ---@param fn fun(report: table[]): nil
  local function with_health(opts, fn)
    local report = {}
    local function record(kind)
      return function(msg, advice) report[#report + 1] = { kind = kind, msg = msg, advice = advice } end
    end

    local original_health = vim.health
    ---@diagnostic disable-next-line: assign-type-mismatch
    vim.health = {
      start = record("start"),
      ok = record("ok"),
      info = record("info"),
      warn = record("warn"),
      error = record("error"),
    }

    local stubs = {
      ["reposcope.utils.checks"] = {
        has_binary = function(name) return opts.available[name] == true end,
        first_available = function() return nil end,
        resolve_request_tool = function() end,
      },
      ["reposcope.config"] = {
        options = {},
        get_option = function(key)
          if key == "request_tool" then return opts.request_tool end
          return nil
        end,
      },
      ["reposcope.utils.env"] = {
        get = function() return opts.token and "gho_x" or nil end,
        has = function() return opts.token == true end,
      },
      -- lib.nvim's command composer is deliberately NOT stubbed: `usrcmds.lua`
      -- registers its routes through it at load time, and `health.lua`'s very
      -- first check is `pcall(require, "reposcope.init")`, which pulls that
      -- file in. A partial double there turns the whole check into "Failed to
      -- load core modules" -- which is exactly the failure this spec would
      -- then be asserting against. Its own `checkhealth` report simply lands
      -- in the recorder alongside reposcope's.
    }

    if opts.images == false then
      package.preload["images.config"] = function() error("not installed", 0) end
    else
      stubs["images.config"] = { get = function() return opts.images end }
    end

    local ok, err = pcall(function()
      H.with_stubs(stubs, { "reposcope.health" }, function()
        require("reposcope.health").check()
        fn(report)
      end)
    end)

    package.preload["images.config"] = nil
    vim.health = original_health
    if not ok then error(err, 0) end
  end

  ---@param report table[]
  ---@param kind string
  ---@param needle string
  ---@return table|nil
  local function entry(report, kind, needle)
    for _, e in ipairs(report) do
      if e.kind == kind and type(e.msg) == "string" and e.msg:find(needle, 1, true) then return e end
    end
    return nil
  end

  ---------------------------------------------------------------------------
  -- Everything in place
  ---------------------------------------------------------------------------
  with_health({
    available = { gh = true, curl = true, wget = true },
    request_tool = "gh",
    token = true,
    images = { display = { remote = { enabled = true, max_bytes = 1024 * 1024 } } },
  }, function(report)
    H.eq(report[1].kind, "start", "the check opens a section")
    H.ok(entry(report, "ok", "Core Reposcope modules loaded"), "the modules load")
    H.ok(entry(report, "ok", "gh is installed"), "each installed tool is reported")
    H.ok(entry(report, "ok", "curl is installed"), "for all of them")
    H.ok(entry(report, "ok", "wget is installed"), "including wget")
    H.ok(entry(report, "ok", "Configured request tool: gh"), "the configured tool is named")
    H.ok(entry(report, "ok", "GITHUB_TOKEN environment variable set"), "the token is acknowledged")
    H.ok(entry(report, "ok", "images.nvim remote images enabled"), "images.nvim is reported as usable")
    H.contains(
      entry(report, "ok", "images.nvim remote images enabled").msg,
      "1.0 MB",
      "with its effective download cap"
    )
    H.falsy(entry(report, "error", ""), "and nothing is an error")
  end)

  ---------------------------------------------------------------------------
  -- One tool missing is not a problem; all three missing is
  ---------------------------------------------------------------------------
  with_health({ available = { curl = true }, request_tool = "curl", token = true, images = false }, function(report)
    -- Only one of the three is needed, so a missing one is informational.
    H.ok(entry(report, "info", "gh is not installed"), "a missing tool is reported as information")
    H.ok(entry(report, "info", "wget is not installed"), "for each of them")
    H.falsy(entry(report, "error", "No usable request tool"), "while another tool is present, this is not an error")
  end)

  with_health({ available = {}, request_tool = "curl", token = true, images = false }, function(report)
    local err = entry(report, "error", "No usable request tool")
    H.ok(err, "with none of the three installed, the plugin cannot work and says so")
    H.ok(err.advice, "with advice attached")
    H.contains(table.concat(err.advice, " "), "Install one of", "naming the remedy")
  end)

  ---------------------------------------------------------------------------
  -- A misconfigured request tool
  ---------------------------------------------------------------------------
  with_health({ available = { curl = true }, request_tool = "httpie", token = true, images = false }, function(report)
    local warn = entry(report, "warn", "Request tool not properly configured")
    H.ok(warn, "a tool outside the supported three is a warning")
    H.contains(warn.msg, "httpie", "naming what was configured")
    H.contains(table.concat(warn.advice, " "), "'gh', 'curl' or 'wget'", "and what is supported")
  end)

  ---------------------------------------------------------------------------
  -- The token is optional, but its absence is worth saying
  ---------------------------------------------------------------------------
  with_health({ available = { curl = true }, request_tool = "curl", token = false, images = false }, function(report)
    local warn = entry(report, "warn", "GITHUB_TOKEN not set")
    H.ok(warn, "a missing token is a warning, not an error -- the plugin still works")
    H.contains(table.concat(warn.advice, " "), "5000", "with the concrete rate-limit difference as the reason")
  end)

  ---------------------------------------------------------------------------
  -- images.nvim: absent, present-but-off, and present-with-a-large-cap
  ---------------------------------------------------------------------------
  with_health({ available = { curl = true }, request_tool = "curl", token = true, images = false }, function(report)
    local info = entry(report, "info", "images.nvim not installed")
    H.ok(info, "images.nvim being absent is information, not a problem")
    H.contains(info.msg, "nothing else is affected", "and the message says the rest of the plugin is unaffected")
  end)

  with_health({
    available = { curl = true },
    request_tool = "curl",
    token = true,
    images = { display = { remote = { enabled = false } } },
  }, function(report)
    local info = entry(report, "info", "remote images are off")
    H.ok(info, "images.nvim installed but not configured for remote images is reported")
    H.contains(info.msg, "display.remote.enabled", "naming the setting to change")
  end)

  with_health({
    available = { curl = true },
    request_tool = "curl",
    token = true,
    images = { display = { remote = { enabled = true } } },
  }, function(report)
    -- No explicit cap: images.nvim's own 20 MB default is what applies, and
    -- the check reports that rather than inventing one of its own.
    H.contains(
      entry(report, "ok", "remote images enabled").msg,
      "20.0 MB",
      "an unset cap is reported as images.nvim's default"
    )
    H.ok(entry(report, "info", "232 kB on average"), "and a cap that large draws a sizing note")
  end)

  with_health(
    {
      available = { curl = true },
      request_tool = "curl",
      token = true,
      images = { display = { remote = { enabled = true, max_bytes = 1024 * 1024 } } },
    },
    function(report) H.falsy(entry(report, "info", "232 kB on average"), "a cap of 1 MB or less needs no sizing note") end
  )
end
