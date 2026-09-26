-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/utils_spec.lua — the small support modules: typed errors, environment
-- reads, the request-tool resolver, the OS helper and the notification gate.

return function(H)
  ---------------------------------------------------------------------------
  -- utils.error: the Result shape everything above it branches on
  ---------------------------------------------------------------------------
  do
    local err_utils = require("reposcope.utils.error")

    local good = err_utils.safe_call(function(a, b) return a + b end, 2, 3)
    H.ok(good.ok, "a call that returns is ok")
    H.eq(good.result, 5, "with its value")
    H.eq(good.err, nil, "and no error")

    local bad = err_utils.safe_call(function() error("kaboom", 0) end)
    H.falsy(bad.ok, "a call that raises is not ok")
    H.eq(bad.result, nil, "has no value")
    H.eq(bad.err, "kaboom", "and carries the raised message")

    -- Arguments are forwarded positionally. `safe_call` packs them with
    -- `{...}` and unpacks with `#args`, so a `nil` in the middle is a hole and
    -- the length operator is free to stop there. Pinned rather than reported
    -- as a defect, because the one shape that actually occurs -- http_client's
    -- seven-argument call, whose fifth (`debug`) is nil on every api_client
    -- request -- lands in the array part and survives intact. It is worth
    -- knowing that this is luck of the allocation, not a guarantee: a caller
    -- with fewer arguments and a nil among them silently loses the rest.
    local truncating = err_utils.safe_call(
      function(a, b, c) return tostring(a) .. "/" .. tostring(b) .. "/" .. tostring(c) end,
      1,
      nil,
      3
    )
    H.eq(truncating.result, "1/nil/nil", "a short call with a nil hole loses everything after it")

    local wide = err_utils.safe_call(function(...)
      local n = select("#", ...)
      return n .. ":" .. tostring((select(7, ...)))
    end, "GET", "url", "cb", "headers", nil, "ctx", "uuid")
    H.eq(wide.result, "7:uuid", "the seven-argument shape http_client actually uses survives the hole")

    -- Only the first return value survives -- worth stating, because the
    -- request tools return through callbacks rather than values for exactly
    -- this reason.
    local multi = err_utils.safe_call(function() return "first", "second" end)
    H.eq(multi.result, "first", "only the first return value is kept")

    local e = err_utils.new_error("NetworkError", "Request failed", { code = 7 })
    H.eq(e.type, "NetworkError", "an error carries its type")
    H.eq(e.message, "Request failed", "its message")
    H.eq(e.details.code, 7, "and optional details")
    H.eq(err_utils.new_error("InvalidStateError", "x").details, nil, "details are optional")
  end

  ---------------------------------------------------------------------------
  -- utils.env: vim.env first, os.getenv second, and the result is cached
  ---------------------------------------------------------------------------
  do
    local env = require("reposcope.utils.env")
    local name = "REPOSCOPE_TEST_ENV_VAR"
    local saved = vim.env[name]

    vim.env[name] = nil
    H.eq(env.get(name), nil, "an unset variable reads as nil")
    H.falsy(env.has(name), "and does not count as set")

    vim.env[name] = ""
    H.eq(env.get(name), nil, "an empty variable is treated as unset")
    H.falsy(env.has(name), "so `has` is false for it too -- an empty token must not look configured")

    vim.env[name] = "value"
    H.eq(env.get(name), "value", "a set variable is returned")
    H.ok(env.has(name), "and counts as set")

    vim.env[name] = saved
  end

  ---------------------------------------------------------------------------
  -- utils.checks: which request tool the plugin will actually use
  ---------------------------------------------------------------------------
  do
    ---Runs the resolver against a scripted view of what is installed.
    ---@param available table<string, boolean>
    ---@param fn fun(checks: table, config: table, notes: string[]): nil
    local function with_checks(available, fn)
      local notes = {}
      H.with_stubs({
        ["lib.nvim.core"] = {
          has_exec = function(name) return available[name] == true end,
          first_available = function(list)
            for _, name in ipairs(list) do
              if available[name] then return name end
            end
            return nil
          end,
        },
        ["reposcope.utils.debug"] = {
          notify = function(msg) notes[#notes + 1] = msg end,
          is_dev_mode = function() return false end,
          debugf = function() end,
          options = { dev_mode = false },
        },
      }, { "reposcope.utils.checks" }, function()
        local config = require("reposcope.config")
        local saved = config.options.request_tool
        local ok, err = pcall(fn, require("reposcope.utils.checks"), config, notes)
        config.options.request_tool = saved
        if not ok then error(err, 0) end
      end)
    end

    with_checks({ gh = true, curl = true }, function(checks, config)
      H.ok(checks.has_binary("gh"), "an installed binary is reported as available")
      H.falsy(checks.has_binary("wget"), "a missing one is not")
      H.eq(checks.first_available({ "wget", "curl", "gh" }), "curl", "the first available wins, in the caller's order")
      H.eq(checks.first_available({ "wget" }), nil, "and nothing is returned when none are there")

      -- Already valid and installed: leave it alone.
      config.options.request_tool = "gh"
      local ok = checks.resolve_request_tool()
      H.ok(ok, "resolution reports success")
      H.eq(config.options.request_tool, "gh", "a configured, installed tool is kept")
    end)

    with_checks({ curl = true }, function(checks, config)
      -- Configured but not installed: fall through to whatever is there.
      config.options.request_tool = "gh"
      local ok = checks.resolve_request_tool()
      H.ok(ok, "resolution reports success")
      H.eq(config.options.request_tool, "curl", "a configured tool that is not installed is replaced")
    end)

    with_checks({ wget = true }, function(checks, config)
      -- A tool that is installed but not in the preference list is still
      -- replaced: the list is the whitelist.
      config.options.request_tool = "httpie"
      local ok = checks.resolve_request_tool({ "gh", "curl", "wget" })
      H.ok(ok, "resolution reports success")
      H.eq(config.options.request_tool, "wget", "an unlisted tool is replaced by the first listed one that exists")
    end)

    with_checks({}, function(checks, config, notes)
      config.options.request_tool = "gh"
      local ok, err = checks.resolve_request_tool()
      -- Nothing to switch to: the stored value is left as it was rather than
      -- being nil'd, so a later error still names a tool -- but resolution
      -- itself is reported as failed regardless of whether a tool was
      -- configured (ERR-03): a configured tool that turns out not to be
      -- installed, with nothing else available either, is exactly this case.
      H.falsy(ok, "with nothing installed, resolution reports failure even though a tool was configured")
      H.contains(err or "", "no request tool available", "and carries a message")
      H.eq(config.options.request_tool, "gh", "the configured value is left in place")
      H.eq(#notes, 1, "and the user is told")
    end)

    with_checks({}, function(checks, config, notes)
      config.options.request_tool = nil
      local ok, err = checks.resolve_request_tool()
      H.falsy(ok, "with nothing configured and nothing installed, resolution reports failure")
      H.contains(err or "", "no request tool available", "and carries a message")
      H.contains(
        notes[1] or "",
        "no request tool available",
        "with nothing configured and nothing installed, the user is told"
      )
    end)
  end

  ---------------------------------------------------------------------------
  -- utils.os
  ---------------------------------------------------------------------------
  do
    local os_utils = require("reposcope.utils.os")
    H.eq(type(os_utils.is_windows()), "boolean", "the platform check answers with a boolean")
    H.eq(
      os_utils.is_windows(),
      vim.uv.os_uname().sysname:find("Windows") ~= nil,
      "and agrees with the running platform"
    )

    -- The URL opener is a one-line delegation; what matters is that a
    -- refusal from the platform layer becomes a message rather than silence.
    local notes = {}
    H.with_stubs({
      ["lib.nvim.cross.open_default"] = function() return false end,
      ["reposcope.utils.debug"] = {
        notify = function(msg) notes[#notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.utils.os" }, function()
      require("reposcope.utils.os").open_url("https://example.invalid")
      H.contains(notes[1] or "", "Unsupported OS for opening URLs", "a refused open is reported")
    end)

    local opened = {}
    H.with_stubs({
      ["lib.nvim.cross.open_default"] = function(url)
        opened[#opened + 1] = url
        return true
      end,
    }, { "reposcope.utils.os" }, function()
      require("reposcope.utils.os").open_url("https://example.invalid/x")
      H.eq(opened[1], "https://example.invalid/x", "a URL is handed to the platform opener unmodified")
    end)
  end

  ---------------------------------------------------------------------------
  -- utils.debug: the notification gate
  ---------------------------------------------------------------------------
  do
    local seen = {}
    local original_notify = vim.notify
    -- Messages are delivered through `lib.nvim.notify.popup`, not vim.notify.
    local popup = require("lib.nvim.notify.popup")
    local popup_deliver = popup.deliver
    popup.deliver = function(msg, level) seen[#seen + 1] = { msg = msg, level = level } end

    local ok, err = pcall(function()
      H.with_stubs({}, { "reposcope.utils.debug" }, function()
        local dbg = require("reposcope.utils.debug")
        dbg.set_dev_mode(false)
        H.falsy(dbg.is_dev_mode(), "dev mode can be turned off")
        H.falsy(dbg.dev_mode, "and the metatable alias agrees")

        dbg.notify("a chatty message", 2)
        dbg.notify("a warning", 3)
        dbg.notify("an error", 4)
        vim.wait(20)
        -- Levels below WARN are development noise; they must not reach a user
        -- who never asked for them. This is what makes the list-navigation path
        -- silent in normal use.
        H.eq(#seen, 2, "outside dev mode only WARN and above are shown")
        H.eq(seen[1].msg, "a warning", "the warning got through")
        H.eq(seen[2].msg, "an error", "and the error")

        seen = {}
        dbg.toggle_dev_mode()
        H.ok(dbg.is_dev_mode(), "dev mode can be toggled on")
        H.ok(dbg.dev_mode, "and the alias follows")
        dbg.notify("now visible", 2)
        vim.wait(20)
        H.eq(#seen, 1, "in dev mode the quiet levels are shown too")

        -- An omitted level defaults to INFO, i.e. dev-mode-only.
        seen = {}
        dbg.set_dev_mode(false)
        dbg.notify("no level given")
        vim.wait(20)
        H.eq(#seen, 0, "an omitted level defaults to the quiet one")

        -- debugf is gated the same way and names its caller.
        seen = {}
        dbg.debugf("context please")
        vim.wait(20)
        H.eq(#seen, 0, "debugf is silent outside dev mode")

        dbg.set_dev_mode(true)
        dbg.debugf("context please")
        vim.wait(20)
        H.eq(#seen, 1, "and speaks inside it")
        H.contains(seen[1].msg, "context please", "carrying the message")
        H.contains(seen[1].msg, "called in function", "plus the calling location")

        H.eq(dbg.no_such_key, nil, "the metatable answers only for dev_mode")
      end)
    end)

    vim.notify = original_notify
    popup.deliver = popup_deliver
    require("reposcope.utils.debug").set_dev_mode(false)
    if not ok then error(err, 0) end
  end
end
