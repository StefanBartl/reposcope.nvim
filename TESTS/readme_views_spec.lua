-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/readme_views_spec.lua — the two README actions bound to the prompt:
-- `<C-b>` (editor: a plain, editable buffer) and `<C-v>` (viewer: a read-only
-- fullscreen float).
--
-- Both share one decision that is easy to get wrong and invisible when it is:
-- a README that is actually HTML is opened in the browser instead of being
-- dumped as markup into a markdown buffer. The caches and the URL opener are
-- stubbed; the buffers and the window are real.

return function(H)
  local ui_state = require("reposcope.state.ui.ui_state")

  ---@param env table
  ---@param module string
  ---@param fn fun(action: table, env: table): nil
  local function with_action(env, module, fn)
    env.opened_urls = {}
    env.notes = {}
    env.autocmds = {}

    H.with_stubs({
      ["reposcope.cache.repository_cache"] = {
        get_selected = function() return env.selected end,
      },
      ["reposcope.cache.readme_cache"] = {
        get = function() return env.content end,
        get_ram = function() return env.ram end,
        get_file = function() return env.file end,
      },
      ["reposcope.utils.os"] = {
        open_url = function(url) env.opened_urls[#env.opened_urls + 1] = url end,
        is_windows = function() return false end,
      },
      ["reposcope.ui.prompt.prompt_autocmds"] = {
        setup_autocmds = function() env.autocmds[#env.autocmds + 1] = "setup" end,
        cleanup_autocmds = function() env.autocmds[#env.autocmds + 1] = "cleanup" end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { module }, function() fn(require(module), env) end)
  end

  local REPO = { name = "telescope.nvim", owner = { login = "nvim-telescope" } }

  ---Every buffer whose name contains `needle`.
  local function buffers_named(needle)
    local found = {}
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf):find(needle, 1, true) then
        found[#found + 1] = buf
      end
    end
    return found
  end

  ---------------------------------------------------------------------------
  -- readme_editor
  ---------------------------------------------------------------------------
  with_action({}, "reposcope.ui.actions.readme_editor", function(editor, env)
    editor.open_editor()
    H.contains(env.notes[1], "No repository selected", "with nothing selected the editor says so")

    env.selected = { owner = { login = "o" } }
    editor.open_editor()
    H.contains(env.notes[2], "No repository selected", "and a selection without a name is the same non-event")
  end)

  with_action({ selected = REPO, ram = "# From RAM\n\nbody" }, "reposcope.ui.actions.readme_editor", function(editor)
    local before = #buffers_named("reposcope://README.md")
    editor.open_editor()

    local buffers = buffers_named("reposcope://README.md (telescope.nvim)")
    H.eq(#buffers, before + 1, "a buffer is created for the README")
    local buf = buffers[#buffers]
    local lines = vim.api.nvim_buf_get_lines(buf, 0, -1, false)
    H.eq(lines[1], "# From RAM", "with the cached content, split into lines")
    H.eq(lines[3], "body", "all of it")
    H.eq(vim.bo[buf].filetype, "markdown", "rendered as markdown")
    -- Editable on purpose: this is the half of the pair that exists so the
    -- README can be edited or scripted against, unlike the viewer.
    H.ok(vim.bo[buf].modifiable, "and editable -- that is what distinguishes it from the viewer")
    H.falsy(vim.bo[buf].readonly, "not read-only")

    vim.api.nvim_buf_delete(buf, { force = true })
  end)

  -- RAM first, disk second, and a placeholder rather than an empty buffer.
  with_action({ selected = REPO, file = "# From disk" }, "reposcope.ui.actions.readme_editor", function(editor, env)
    editor.open_editor()
    local buffers = buffers_named("reposcope://README.md (telescope.nvim)")
    H.eq(
      vim.api.nvim_buf_get_lines(buffers[#buffers], 0, -1, false)[1],
      "# From disk",
      "a RAM miss falls through to the file cache"
    )
    H.contains(table.concat(env.notes, "\n"), "README not cached for", "and says it had to")
    vim.api.nvim_buf_delete(buffers[#buffers], { force = true })
  end)

  with_action({ selected = REPO }, "reposcope.ui.actions.readme_editor", function(editor, env)
    editor.open_editor()
    local buffers = buffers_named("reposcope://README.md (telescope.nvim)")
    H.eq(
      vim.api.nvim_buf_get_lines(buffers[#buffers], 0, -1, false)[1],
      "README not cached yet.",
      "with nothing cached at all, a sentence is shown rather than an empty buffer"
    )
    H.contains(table.concat(env.notes, "\n"), "not filecached", "and both misses are reported")
    vim.api.nvim_buf_delete(buffers[#buffers], { force = true })
  end)

  -- A README that is really HTML: rendering it as markdown would show markup.
  for _, markup in ipairs({ "<html>x</html>", "<head>x", "<body>x", "<div>x</div>" }) do
    with_action({ selected = REPO, ram = markup }, "reposcope.ui.actions.readme_editor", function(editor, env)
      local before = #buffers_named("reposcope://README.md")
      editor.open_editor()
      H.eq(#env.opened_urls, 1, "HTML content goes to the browser instead: " .. markup)
      H.eq(env.opened_urls[1], "https://github.com/nvim-telescope/telescope.nvim", "at the repository's page")
      H.eq(#buffers_named("reposcope://README.md"), before, "and no buffer is created")
    end)
  end

  ---------------------------------------------------------------------------
  -- readme_viewer
  ---------------------------------------------------------------------------
  with_action({}, "reposcope.ui.actions.readme_viewer", function(viewer, env)
    viewer.open_viewer()
    H.contains(env.notes[1], "No repository selected", "with nothing selected the viewer says so")
  end)

  with_action({ selected = REPO }, "reposcope.ui.actions.readme_viewer", function(viewer, env)
    viewer.open_viewer()
    H.eq(ui_state.buffers.readme_viewer, nil, "an uncached README opens nothing at all")
    H.eq(#env.opened_urls, 0, "and does not fall back to the browser either")
  end)

  with_action(
    { selected = REPO, content = "<html><body>x</body></html>" },
    "reposcope.ui.actions.readme_viewer",
    function(viewer, env)
      viewer.open_viewer()
      H.eq(#env.opened_urls, 1, "an HTML README opens in the browser")
      H.eq(env.opened_urls[1], "https://github.com/nvim-telescope/telescope.nvim", "at the repository's page")
      H.eq(ui_state.buffers.readme_viewer, nil, "without creating a viewer buffer")
      H.contains(table.concat(env.notes, "\n"), "Opened in browser", "and the user is told where it went")
    end
  )

  with_action(
    { selected = REPO, content = "# Telescope\n\nFind files" },
    "reposcope.ui.actions.readme_viewer",
    function(viewer, env)
      local saved_buf, saved_win = ui_state.buffers.readme_viewer, ui_state.windows.readme_viewer
      ui_state.buffers.readme_viewer, ui_state.windows.readme_viewer = nil, nil
      local windows_before = #vim.api.nvim_list_wins()

      local ok, err = pcall(function()
        viewer.open_viewer()

        local buf = ui_state.buffers.readme_viewer
        H.ok(buf and vim.api.nvim_buf_is_valid(buf), "a viewer buffer is created")
        H.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "# Telescope", "holding the cached README")
        H.eq(vim.bo[buf].filetype, "markdown", "as markdown")
        -- Read-only, unlike the editor: this one is for looking at.
        H.falsy(vim.bo[buf].modifiable, "and not modifiable")
        H.ok(vim.bo[buf].readonly, "explicitly read-only")
        H.eq(vim.bo[buf].buftype, "nofile", "and not backed by a file")

        local win = ui_state.windows.readme_viewer
        H.ok(win and vim.api.nvim_win_is_valid(win), "a window is opened for it")
        H.eq(#vim.api.nvim_list_wins(), windows_before + 1, "exactly one")
        H.eq(vim.api.nvim_get_current_win(), win, "and focused")
        H.ok(vim.wo[win].wrap, "with wrapping on, since README lines are prose")

        -- The prompt's own autocmds have to stand down while the viewer owns
        -- the screen, or the cursor lock fights the reader.
        H.has(env.autocmds, "cleanup", "the prompt autocmds are torn down while the viewer is up")

        local has_q = false
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
          if m.lhs == "q" then has_q = true end
        end
        H.ok(has_q, "`q` is bound to close the viewer")

        -- BUG: opening the viewer a second time while it is still open raises
        -- "Invalid buffer id". `_prepare_readme_buffer` reuses the existing
        -- buffer and hands it back, and only *then* does `_open_readme_window`
        -- close the previous window -- which, because the buffer carries
        -- `bufhidden = "wipe"`, takes the buffer with it. The very next line
        -- passes that now-dead handle to `nvim_open_win`.
        --
        -- Reachable in practice, and the route goes through the keymap defect
        -- pinned in `bindings_spec.lua`: `_open_readme_window` calls
        -- `unset_prompt_keymaps()` precisely so `<C-v>` cannot fire again --
        -- and that call removes nothing, so leaving the viewer window without
        -- closing it and pressing `<C-v>` in the prompt reaches exactly this.
        --
        -- The reuse branch has a second, smaller flaw visible on the way: it
        -- restores `modifiable` but not `readonly`, so the write that follows
        -- emits "W10: Warning: Changing a readonly file".
        local reopen_ok, reopen_err = pcall(viewer.open_viewer)
        H.falsy(reopen_ok, "BUG: reopening the viewer while it is open raises")
        H.contains(tostring(reopen_err), "Invalid buffer id", "BUG: the reused buffer was wiped with the old window")
        H.falsy(vim.api.nvim_buf_is_valid(buf), "BUG: and it really is gone, not merely unreferenced")

        viewer.close_viewer()
        H.eq(ui_state.buffers.readme_viewer, nil, "closing forgets the buffer")
        H.has(env.autocmds, "setup", "and the prompt autocmds are put back")
      end)

      -- `bufhidden = "wipe"` means closing the window already took the buffer.
      if ui_state.windows.readme_viewer and vim.api.nvim_win_is_valid(ui_state.windows.readme_viewer) then
        vim.api.nvim_win_close(ui_state.windows.readme_viewer, true)
      end
      ui_state.buffers.readme_viewer, ui_state.windows.readme_viewer = saved_buf, saved_win
      if not ok then error(err, 0) end
    end
  )

  with_action({ selected = REPO }, "reposcope.ui.actions.readme_viewer", function(viewer, env)
    -- An invalid buffer handle must be refused rather than raising out of
    -- nvim_buf_set_keymap.
    viewer.set_viewer_keymap(nil)
    viewer.set_viewer_keymap(999999)
    H.contains(
      table.concat(env.notes, "\n"),
      "buffer is invalid",
      "setting the keymap on a dead buffer is reported, not raised"
    )

    -- Closing when nothing is open is a no-op, which matters because `q` and
    -- `:Reposcope close` can both reach it.
    local ok = pcall(viewer.close_viewer)
    H.ok(ok, "closing a viewer that is not open is harmless")
  end)
end
