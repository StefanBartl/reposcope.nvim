-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/protection_spec.lua — `utils.protection`: filesystem safety, the
-- named-buffer registry, the debounce wrappers and the two shell entry
-- points. The directory work runs against a real fixture; the shell work is
-- stubbed, so nothing is executed.

return function(H)
  local protection = require("reposcope.utils.protection")
  local dir, cleanup = H.fixture("protection")

  local ok, err = pcall(function()
    -------------------------------------------------------------------------
    -- count_or_default
    -------------------------------------------------------------------------
    H.eq(protection.count_or_default({ "a", "b" }, 7), 2, "a non-empty table counts its entries")
    H.eq(protection.count_or_default({ x = 1, y = 2, z = 3 }, 7), 3, "including a map")
    H.eq(protection.count_or_default({}, 7), 7, "an empty table falls back to the default")
    H.eq(protection.count_or_default(5, 7), 5, "a non-zero number is itself")
    H.eq(protection.count_or_default(0, 7), 7, "zero falls back")
    H.eq(protection.count_or_default("", 7), 7, "and so does anything else")
    H.eq(protection.count_or_default(nil, 7), 7, "nil included")

    -------------------------------------------------------------------------
    -- is_valid_filename
    -------------------------------------------------------------------------
    H.ok(protection.is_valid_filename("report.md"), "an ordinary filename is valid")
    H.ok(protection.is_valid_filename("a name with spaces.txt"), "spaces are allowed")

    local valid, reason = protection.is_valid_filename(nil)
    H.falsy(valid, "nil is not a filename")
    H.contains(reason, "nil", "and says so")

    valid, reason = protection.is_valid_filename("")
    H.falsy(valid, "neither is the empty string")
    H.contains(reason, "missing", "which is reported separately from nil")

    valid, reason = protection.is_valid_filename("   ")
    H.falsy(valid, "nor whitespace only")
    H.contains(reason, "whitespace", "with its own reason")

    -- The rejected set is the union of the Windows and POSIX restrictions, so
    -- a name accepted here is portable.
    for _, bad in ipairs({ "a/b", "a\\b", "a:b", "a*b", "a?b", 'a"b', "a<b", "a>b", "a|b" }) do
      valid, reason = protection.is_valid_filename(bad)
      H.falsy(valid, "a reserved character is refused: " .. bad)
      H.contains(reason, "invalid characters", "with the shared reason")
    end

    -------------------------------------------------------------------------
    -- safe_mkdir / is_dir_writeable
    -------------------------------------------------------------------------
    local nested = dir .. "/a/b/c"
    H.eq(vim.fn.isdirectory(nested), 0, "the nested directory does not exist yet")
    H.ok(protection.safe_mkdir(nested), "safe_mkdir creates it, parents included")
    H.eq(vim.fn.isdirectory(nested), 1, "and it is really there")
    H.ok(protection.safe_mkdir(nested), "creating an existing directory succeeds without doing anything")

    H.ok(protection.is_dir_writeable(nested), "a freshly created directory is writable")
    H.eq(vim.fn.filereadable(nested .. "/.rs_write_test"), 0, "and the probe file is removed again")

    -- A path occupied by a *file* cannot become a directory. The point of
    -- safe_mkdir is that this is reported rather than raised.
    local blocker = dir .. "/occupied"
    vim.fn.writefile({ "x" }, blocker)
    H.falsy(protection.safe_mkdir(blocker .. "/child"), "a file in the way makes safe_mkdir report failure")

    -------------------------------------------------------------------------
    -- is_valid_path
    -------------------------------------------------------------------------
    local made = dir .. "/logs"
    H.ok(protection.is_valid_path(made .. "/", false), "a directory path is validated and created")
    H.eq(vim.fn.isdirectory(made), 1, "the directory now exists -- this call has a side effect by design")

    H.ok(
      protection.is_valid_path(dir .. "/logs2/request_log.json", true),
      "a file path validates its parent and its name"
    )
    H.eq(vim.fn.isdirectory(dir .. "/logs2"), 1, "creating the parent on the way")

    H.falsy(protection.is_valid_path(dir .. "/logs3/bad:name.json", true), "an unusable filename fails validation")

    -- Windows: a path spelled with backslashes and no trailing separator is
    -- the normal shape of `vim.fn.expand("~")` and of anything Tab-completed
    -- from `:Reposcope dashboard`. The separator normalisation has to cope.
    local win_style = dir:gsub("/", "\\") .. "\\winstyle"
    H.ok(protection.is_valid_path(win_style, false), "a backslash-spelled directory path is accepted")
    H.eq(vim.fn.isdirectory(dir .. "/winstyle"), 1, "and creates the directory it names")

    -- BUG: `nec_filename` is documented as optional, but omitting it is the
    -- one call shape that cannot work. With `nil`, `filename` is never
    -- assigned; the `if dir_ok and nec_filename == false` early return does
    -- not fire (nil is not false), so the code falls through to
    --   debugf("... " .. dir .. "/" .. filename .. " ...")
    -- and raises "attempt to concatenate a nil value" -- eagerly, before
    -- `debugf`'s own dev-mode gate is ever consulted, so it happens whether
    -- or not developer mode is on. The function has no in-repo caller today,
    -- which is why it has gone unnoticed; it is public API all the same.
    local ok_default, err_default = pcall(protection.is_valid_path, dir .. "/whatever/")
    H.falsy(ok_default, "BUG: omitting the optional second argument raises")
    H.contains(tostring(err_default), "concatenate", "BUG: on a nil filename in the error path")

    -------------------------------------------------------------------------
    -- create_named_buffer
    -------------------------------------------------------------------------
    do
      local ui_state = require("reposcope.state.ui.ui_state")
      local saved = vim.deepcopy(ui_state.buffers)

      local buf = protection.create_named_buffer("reposcope://preview")
      H.ok(buf, "a buffer is created")
      H.ok(vim.api.nvim_buf_is_valid(buf), "and is valid")
      H.contains(vim.api.nvim_buf_get_name(buf), "reposcope://preview", "carrying the requested name")
      H.eq(ui_state.buffers.preview, buf, "a known name is registered in the UI state")

      -- Asking again replaces: Neovim refuses two buffers with the same name,
      -- so the previous one has to go first.
      local second = protection.create_named_buffer("reposcope://preview")
      H.ok(second ~= buf, "asking again yields a new buffer")
      H.falsy(vim.api.nvim_buf_is_valid(buf), "and the previous one is deleted")
      H.eq(ui_state.buffers.preview, second, "with the state pointing at the new one")

      -- An unknown name still produces a usable buffer, it just is not tracked.
      local untracked = protection.create_named_buffer("reposcope://stats")
      H.ok(vim.api.nvim_buf_is_valid(untracked), "an unregistered name still yields a buffer")
      H.eq(ui_state.buffers.stats, nil, "which is not written into the state table")

      for _, b in ipairs({ second, untracked }) do
        if vim.api.nvim_buf_is_valid(b) then vim.api.nvim_buf_delete(b, { force = true }) end
      end
      for k in pairs(ui_state.buffers) do
        ui_state.buffers[k] = nil
      end
      for k, v in pairs(saved) do
        ui_state.buffers[k] = v
      end
    end

    -------------------------------------------------------------------------
    -- debounce
    -------------------------------------------------------------------------
    do
      local calls = 0
      local call = protection.debounce(function() calls = calls + 1 end, 20)
      call()
      call()
      call()
      H.eq(calls, 0, "nothing runs while the timer is still pending")
      vim.wait(200, function() return calls > 0 end)
      H.eq(calls, 1, "three rapid calls collapse into one -- this is the list-navigation guard")

      local ran = 0
      local counted, skipped = protection.debounce_with_counter(function() ran = ran + 1 end, 20)
      counted()
      counted()
      counted()
      vim.wait(200, function() return ran > 0 end)
      H.eq(ran, 1, "the counting variant also runs once")
      H.eq(skipped(), 2, "and reports how many calls it swallowed -- what `:Reposcope skipped-readmes` prints")
    end

    -------------------------------------------------------------------------
    -- The two shell entry points
    -------------------------------------------------------------------------
    do
      local argv_calls = {}
      H.with_stubs({
        ["lib.nvim.cross.run_argv"] = {
          run_blocking_captured = function(cmd)
            argv_calls[#argv_calls + 1] = { mode = "blocking", cmd = cmd }
            return true, "captured output"
          end,
          run_async_captured = function(cmd, on_done)
            argv_calls[#argv_calls + 1] = { mode = "async", cmd = cmd }
            on_done(false, "it failed")
            return { stop = function() end }
          end,
        },
      }, { "reposcope.utils.protection" }, function()
        local p = require("reposcope.utils.protection")

        local success, output = p.safe_execute_shell({ "git", "status", "--porcelain" })
        H.eq(argv_calls[1].mode, "blocking", "an argv table goes to the argv runner")
        H.eq(argv_calls[1].cmd[2], "status", "unchanged")
        H.ok(success, "and its result is passed through")
        H.eq(output, "captured output", "output included")

        local got
        local handle = p.safe_execute_shell_async(
          { "git", "clone", "url", "dir" },
          function(s, o) got = { s = s, o = o } end
        )
        H.eq(argv_calls[2].mode, "async", "the async form goes to the async runner")
        H.eq(#argv_calls[2].cmd, 4, "with the whole argv")
        H.falsy(got.s, "a failure is reported through the callback")
        H.eq(got.o, "it failed", "with the output")
        H.eq(type(handle.stop), "function", "and the caller gets a handle it can stop")
      end)

      -- The string form goes through `vim.fn.system`, which is bound to a
      -- file-local at load time -- so it has to be replaced before the reload.
      local original_system = vim.fn.system
      local seen_cmd
      ---@diagnostic disable-next-line: duplicate-set-field
      vim.fn.system = function(cmd)
        seen_cmd = cmd
        vim.v.errmsg = ""
        return "shell output"
      end
      local ok_shell, err_shell = pcall(function()
        H.with_stubs({}, { "reposcope.utils.protection" }, function()
          local p = require("reposcope.utils.protection")
          local success, output = p.safe_execute_shell("echo hi")
          H.eq(seen_cmd, "echo hi", "a string command is handed to vim.fn.system verbatim")
          H.eq(type(success), "boolean", "the result is a boolean")
          H.eq(output, "shell output", "with the captured output")
        end)
      end)
      vim.fn.system = original_system
      if not ok_shell then error(err_shell, 0) end
    end
  end)

  cleanup()
  if not ok then error(err, 0) end
end
