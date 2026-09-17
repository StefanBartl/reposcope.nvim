-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/bindings_spec.lua — the wiring: the single `:Reposcope` command and
-- its subcommands, the keymap layer, and the QuitPre autocmd.
--
-- The command is driven through real `:Reposcope ...` calls and real
-- `getcompletion()` requests, with every feature module stubbed in
-- `package.loaded` before `bindings/usrcmds.lua` is (re)loaded -- it captures
-- its collaborators into file-locals while registering the routes.

return function(H)
  ---------------------------------------------------------------------------
  -- :Reposcope
  ---------------------------------------------------------------------------
  ---@param env table
  ---@param fn fun(env: table): nil
  local function with_command(env, fn)
    env.calls = {}
    env.notes = {}
    env.printed = {}

    local function record(what)
      return function(...) env.calls[#env.calls + 1] = { what = what, args = { ... } } end
    end

    H.with_stubs({
      ["reposcope.init"] = {
        open_ui = record("open_ui"),
        close_ui = record("close_ui"),
        setup = function() end,
      },
      ["reposcope.controllers.list_controller"] = { display_repositories = record("display") },
      ["reposcope.cache.repository_cache"] = {
        restore_relevance_sorting = record("restore_relevance"),
        get = function() return { items = env.items or {} } end,
      },
      ["reposcope.ui.prompt.prompt_config"] = {
        get_available_fields = function() return { "keywords", "owner" } end,
        get_fields = function() return {} end,
        set_fields = function() end,
        recompute = function() end,
      },
      ["reposcope.ui.actions.prompt_reload"] = { reload_prompt = record("reload_prompt") },
      ["reposcope.ui.actions.filter_prompt"] = { prompt_filter = record("filter_prompt") },
      ["reposcope.ui.actions.filter_repos"] = {
        apply_filter = record("apply_filter"),
        get_current_filter = function() return "" end,
      },
      ["reposcope.ui.actions.sort_prompt"] = {
        prompt_sort = record("prompt_sort"),
        get_current_sort = function() return "relevance" end,
      },
      ["reposcope.controllers.provider_controller"] = {
        fetch_readme_for_selected = record("fetch_readme"),
        get_active_provider = function() return "github" end,
        get_registered_providers = function() return { "codeberg", "github", "gitlab" } end,
        get_skipped_fetches = function() return 7 end,
      },
      ["reposcope.ui.actions.status_view"] = {
        show = function(records, opts)
          env.calls[#env.calls + 1] = { what = "status_view", records = records, opts = opts }
        end,
      },
      ["reposcope.ui.actions.favorites_view"] = { show = record("favorites_view") },
      ["reposcope.state.favorites_state"] = { clear_all = record("favorites_clear"), list = function() return {} end },
      ["reposcope.state.session_state"] = {
        save = record("session_save"),
        restore = record("session_restore"),
        clear = record("session_clear"),
      },
      ["reposcope.state.query_stats"] = {
        top = function(n)
          env.calls[#env.calls + 1] = { what = "queries_top", args = { n } }
          return env.top or {}
        end,
        clear_all = record("queries_clear"),
      },
      ["reposcope.utils.stats"] = { show_stats = record("show_stats") },
      ["reposcope.utils.repo_status"] = {
        status_all = function(path, on_complete)
          env.calls[#env.calls + 1] = { what = "status_all", path = path }
          on_complete(env.records or {}, env.errors or {})
        end,
      },
      ["reposcope.utils.repo_updater"] = {
        update_all = function(path, on_complete)
          env.calls[#env.calls + 1] = { what = "update_all", path = path }
          on_complete(env.updated or 0, env.update_errors or {})
        end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        toggle_dev_mode = record("toggle_dev"),
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = true },
      },
    }, { "reposcope.bindings.usrcmds" }, function()
      local original_print = _G.print
      ---@diagnostic disable-next-line: duplicate-set-field
      _G.print = function(...)
        local parts = {}
        for i = 1, select("#", ...) do
          parts[#parts + 1] = tostring((select(i, ...)))
        end
        env.printed[#env.printed + 1] = table.concat(parts, " ")
      end

      require("reposcope.bindings.usrcmds")
      local ok, err = pcall(fn, env)

      _G.print = original_print
      if not ok then error(err, 0) end
    end)
  end

  ---@param env table
  ---@param what string
  ---@return table|nil
  local function find(env, what)
    for _, call in ipairs(env.calls) do
      if call.what == what then return call end
    end
    return nil
  end

  -- The command exists and dispatches -------------------------------------
  with_command({}, function(env)
    H.ok(vim.fn.exists(":Reposcope") == 2, "a single :Reposcope command is registered")

    vim.cmd("Reposcope start")
    H.ok(find(env, "open_ui"), "`start` opens the UI")

    vim.cmd("Reposcope close")
    H.ok(find(env, "close_ui"), "`close` closes it")

    vim.cmd("Reposcope sort")
    H.ok(find(env, "prompt_sort"), "`sort` opens the sort menu")

    vim.cmd("Reposcope stats")
    H.ok(find(env, "show_stats"), "`stats` opens the statistics window")

    vim.cmd("Reposcope filter-prompt")
    H.ok(find(env, "filter_prompt"), "`filter-prompt` opens the interactive filter")

    vim.cmd("Reposcope toggle-dev")
    H.ok(find(env, "toggle_dev"), "`toggle-dev` toggles developer mode")

    vim.cmd("Reposcope print-dev")
    H.contains(table.concat(env.printed, "\n"), "dev_mode", "`print-dev` prints the current mode")

    vim.cmd("Reposcope skipped-readmes")
    H.contains(table.concat(env.printed, "\n"), "7", "`skipped-readmes` prints the debounce counter")
  end)

  -- Arguments reach their handler ------------------------------------------
  with_command({}, function(env)
    vim.cmd("Reposcope prompt prefix keywords owner")
    local reload = find(env, "reload_prompt")
    H.ok(reload, "`prompt` reaches its handler")
    H.eq(table.concat(reload.args[1], " "), "prefix keywords owner", "with every field name, in order")

    vim.cmd("Reposcope filter lua plugin")
    local filter = find(env, "apply_filter")
    -- The filter is a substring, so the remaining tokens have to be rejoined
    -- rather than treated as separate arguments.
    H.eq(filter.args[1], "lua plugin", "`filter` rejoins its arguments into one substring")

    vim.cmd("Reposcope filter")
    H.eq(env.calls[#env.calls].args[1], "", "and with no arguments it applies the empty filter, which resets")
  end)

  with_command({}, function(env)
    vim.cmd("Reposcope filter-clear")
    H.ok(find(env, "restore_relevance"), "`filter-clear` restores the original order")
    H.ok(find(env, "display"), "redraws the list")
    H.ok(find(env, "fetch_readme"), "and refreshes the preview")
    H.contains(table.concat(env.notes, "\n"), "Filter reset", "telling the user")
  end)

  -- The three-way subcommands ----------------------------------------------
  with_command({}, function(env)
    vim.cmd("Reposcope session save")
    H.ok(find(env, "session_save"), "`session save` saves")
    vim.cmd("Reposcope session restore")
    H.ok(find(env, "session_restore"), "`session restore` restores")
    vim.cmd("Reposcope session clear")
    H.ok(find(env, "session_clear"), "`session clear` clears")

    vim.cmd("Reposcope session")
    H.contains(table.concat(env.notes, "\n"), "session save|restore|clear", "and a bare `session` prints its usage")
    vim.cmd("Reposcope session nonsense")
    H.contains(table.concat(env.notes, "\n"), "session save|restore|clear", "as does an unknown action")
  end)

  with_command({}, function(env)
    vim.cmd("Reposcope favorites")
    H.ok(find(env, "favorites_view"), "`favorites` defaults to listing")
    vim.cmd("Reposcope favorites clear")
    H.ok(find(env, "favorites_clear"), "`favorites clear` clears them")
    vim.cmd("Reposcope favorites nonsense")
    H.contains(table.concat(env.notes, "\n"), "favorites list|clear", "and an unknown action prints usage")
  end)

  with_command({ top = {} }, function(env)
    vim.cmd("Reposcope queries")
    H.eq(find(env, "queries_top").args[1], 10, "`queries` asks for the top ten")
    H.contains(table.concat(env.notes, "\n"), "No recorded queries yet", "and says so when there are none")
  end)

  with_command({ top = { { query = "nvim", count = 3 }, { query = "telescope", count = 1 } } }, function(env)
    vim.cmd("Reposcope queries")
    local printed = table.concat(env.printed, "\n")
    H.contains(printed, "(3x) nvim", "each query is listed with its count")
    H.contains(printed, "(1x) telescope", "for every entry")
    vim.cmd("Reposcope queries clear")
    H.ok(find(env, "queries_clear"), "`queries clear` clears them")
  end)

  with_command({}, function(env)
    vim.cmd("Reposcope providers")
    local printed = table.concat(env.printed, "\n")
    H.contains(printed, "* github", "the active provider is marked")
    H.contains(printed, "  gitlab", "and the others are not")
    H.contains(printed, "  codeberg", "but are still listed")
  end)

  -- update / status --------------------------------------------------------
  with_command({ updated = 3 }, function(env)
    vim.cmd("Reposcope update")
    local call = find(env, "update_all")
    H.ok(call, "`update` runs the directory-wide update")
    H.eq(call.path, nil, "with no path, meaning the configured clone directory")
    H.contains(table.concat(env.notes, "\n"), "Updated 3 repositories successfully", "and reports the count")
  end)

  with_command({ updated = 1, update_errors = { "broken: fatal" } }, function(env)
    vim.cmd("Reposcope update")
    local reported = table.concat(env.notes, "\n")
    H.contains(reported, "Updated 1 repository, 1 failed", "a partial result reports both halves, in the singular")
    H.contains(reported, "broken: fatal", "and lists what failed")
  end)

  with_command({ records = { { name = "a" } } }, function(env)
    -- `status` takes a directory argument, which must exist -- the route's
    -- type validates it, so the repository root itself is used here.
    vim.cmd("Reposcope status " .. vim.fn.getcwd())
    local call = find(env, "status_all")
    H.ok(call, "`status` reads the overview")
    H.contains(call.path, "reposcope", "for the directory that was named")

    local view = find(env, "status_view")
    H.ok(view, "and shows it")
    H.eq(#view.records, 1, "with the records it read")
    -- The directory is carried into the view so its own rescan key re-reads
    -- what was asked for, not the configured default.
    H.contains(view.opts.dir, "reposcope", "carrying the directory through, for the view's own rescan")
  end)

  with_command({ records = { { name = "a" } } }, function(env)
    vim.cmd("Reposcope status " .. vim.fn.getcwd() .. " --out=buffer")
    H.eq(find(env, "status_view").opts.output, "buffer", "the --out flag selects the output backend")
  end)

  with_command({ records = {}, errors = { "a: unreadable", "b: unreadable" } }, function(env)
    vim.cmd("Reposcope status " .. vim.fn.getcwd())
    H.falsy(find(env, "status_view"), "with no readable repository, nothing is shown")
    local reported = table.concat(env.notes, "\n")
    H.contains(reported, "2 repositories could not be read", "but the failures are reported, in the plural")
    H.contains(reported, "a: unreadable", "naming each one")
  end)

  with_command({ records = { { name = "a" } }, errors = { "b: unreadable" } }, function(env)
    vim.cmd("Reposcope status " .. vim.fn.getcwd())
    H.ok(find(env, "status_view"), "a partial read still shows what was readable")
    H.contains(table.concat(env.notes, "\n"), "1 repository could not be read", "and reports the rest, in the singular")
  end)

  -- Completion -------------------------------------------------------------
  with_command({
    items = {
      { name = "telescope.nvim", owner = { login = "nvim-telescope" } },
      { name = "fzf-lua", owner = { login = "ibhagwan" } },
    },
  }, function()
    local subcommands = vim.fn.getcompletion("Reposcope ", "cmdline")
    for _, expected in ipairs({
      "start",
      "close",
      "status",
      "update",
      "filter",
      "prompt",
      "session",
      "favorites",
      "queries",
    }) do
      H.has(subcommands, expected, "the subcommand is offered: " .. expected)
    end

    H.eq(
      table.concat(vim.fn.getcompletion("Reposcope session ", "cmdline"), ","),
      "save,restore,clear",
      "`session` completes its three actions"
    )
    H.eq(
      table.concat(vim.fn.getcompletion("Reposcope favorites ", "cmdline"), ","),
      "list,clear",
      "`favorites` completes its two"
    )

    -- The filter is a substring over what is on screen, so the only
    -- candidates that can match anything are the owners and names actually in
    -- the current result set.
    local filter_candidates = vim.fn.getcompletion("Reposcope filter ", "cmdline")
    H.has(filter_candidates, "telescope.nvim", "`filter` completes against the repositories on screen")
    H.has(filter_candidates, "nvim-telescope", "owners included, because filtering to one owner is the common case")
    H.eq(
      table.concat(vim.fn.getcompletion("Reposcope filter fzf", "cmdline"), ","),
      "fzf-lua",
      "and is filtered by what is typed"
    )

    H.has(vim.fn.getcompletion("Reposcope prompt ", "cmdline"), "keywords", "`prompt` completes field names")
  end)

  ---------------------------------------------------------------------------
  -- keymaps
  ---------------------------------------------------------------------------
  do
    local keymaps = require("reposcope.bindings.keymaps")
    local ui_state = require("reposcope.state.ui.ui_state")
    local config = require("reposcope.config")
    local saved_buffers = vim.deepcopy(ui_state.buffers)
    local saved_prompt_keymaps = vim.deepcopy(config.options.prompt_keymaps)

    local ok, err = pcall(function()
      -- The cheatsheet is generated from the same table `set_prompt_keymaps`
      -- registers from, so it cannot drift from what is actually bound.
      local rows = keymaps.list_active_prompt_keymaps()
      H.ok(#rows >= 10, "the cheatsheet lists the configured prompt actions")
      H.eq(rows[1].action, "confirm", "in a stable display order")
      for _, row in ipairs(rows) do
        H.ok(type(row.desc) == "string" and row.desc ~= "", "every row carries a description: " .. row.action)
        H.ok(type(row.lhs) == "table" and #row.lhs > 0, "and at least one key: " .. row.action)
      end

      local multi
      for _, row in ipairs(rows) do
        if row.action == "focus_next" then multi = row end
      end
      H.ok(#multi.lhs > 1, "an action bound to several keys lists all of them")

      -- Disabling an action removes it from the cheatsheet as well as from
      -- the registration.
      config.options.prompt_keymaps.help = false
      config.options.prompt_keymaps.clone = ""
      local trimmed = keymaps.list_active_prompt_keymaps()
      for _, row in ipairs(trimmed) do
        H.ok(row.action ~= "help", "an action disabled with `false` is gone")
        H.ok(row.action ~= "clone", "and one disabled with an empty string too")
      end
      H.eq(#trimmed, #rows - 2, "exactly the two disabled ones are missing")
      config.options.prompt_keymaps = vim.deepcopy(saved_prompt_keymaps)

      -- Registration against real buffers.
      local a = vim.api.nvim_create_buf(false, true)
      local b = vim.api.nvim_create_buf(false, true)

      ui_state.reset("buffers")
      keymaps.set_prompt_keymaps()
      H.eq(#vim.api.nvim_buf_get_keymap(a, "i"), 0, "without prompt buffers nothing is bound")

      ui_state.buffers.prompt = { keywords = a, owner = b }
      keymaps.set_prompt_keymaps()
      local insert_maps = vim.api.nvim_buf_get_keymap(a, "i")
      H.ok(#insert_maps > 0, "prompt keymaps are bound to every prompt buffer")
      local lhs_seen = {}
      for _, m in ipairs(insert_maps) do
        lhs_seen[m.lhs] = true
      end
      H.ok(lhs_seen["<CR>"], "confirm is bound in insert mode")
      H.ok(#vim.api.nvim_buf_get_keymap(b, "i") > 0, "and to the second buffer as well")

      -- BUG: `unset_prompt_keymaps()` removes nothing. It calls
      -- `_clear_registered_keymaps("reposcope_prompt")`, which matches
      -- registry entries with `map.tag == tag` -- an exact comparison --
      -- while `set_prompt_keymaps()` tags each entry with the *per-field*
      -- name `"reposcope_prompt_" .. field` ("reposcope_prompt_keywords",
      -- ...). The two never compare equal, so every prompt mapping stays
      -- bound and its registry entry is never dropped. The close-UI half
      -- below is unaffected, because it tags with the plain "reposcope_ui".
      --
      -- Survivable in normal use only because `close_ui()` deletes the prompt
      -- buffers immediately afterwards and buffer-local keymaps die with
      -- their buffer. What does not die is `_registry`: it grows by one entry
      -- per mapping per prompt field on every single open/close cycle, for
      -- the life of the session.
      local before_unset = #vim.api.nvim_buf_get_keymap(a, "i")
      keymaps.unset_prompt_keymaps()
      H.eq(#vim.api.nvim_buf_get_keymap(a, "i"), before_unset, "BUG: unsetting the prompt keymaps removes none of them")
      H.ok(#vim.api.nvim_buf_get_keymap(b, "i") > 0, "BUG: on any of the buffers they were put on")

      -- Clean them off by hand, so the rest of this block starts from zero.
      for _, buf in ipairs({ a, b }) do
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "i")) do
          pcall(vim.keymap.del, "i", m.lhs, { buffer = buf })
        end
        for _, m in ipairs(vim.api.nvim_buf_get_keymap(buf, "n")) do
          pcall(vim.keymap.del, "n", m.lhs, { buffer = buf })
        end
      end
      H.eq(#vim.api.nvim_buf_get_keymap(a, "i"), 0, "the buffers are clean again")

      -- The close keymaps go onto the background/preview/list buffers plus
      -- every prompt buffer.
      ui_state.buffers.preview = vim.api.nvim_create_buf(false, true)
      ui_state.buffers.list = vim.api.nvim_create_buf(false, true)
      keymaps.set_close_ui_keymaps()
      -- Matched on `desc` rather than `lhs`: `nvim_buf_get_keymap` reports the
      -- left-hand side in terminal codes, so `<C-w>` comes back as a raw
      -- control byte.
      local descs = {}
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(ui_state.buffers.preview, "n")) do
        descs[m.desc or ""] = true
      end
      H.ok(descs["close the UI"], "<Esc> closes the UI from the preview")
      H.ok(descs["Close Reposcope"], "and so does <C-w>")
      H.ok(#vim.api.nvim_buf_get_keymap(a, "n") > 0, "the prompt buffers get them too")

      local insert_descs = {}
      for _, m in ipairs(vim.api.nvim_buf_get_keymap(ui_state.buffers.preview, "i")) do
        insert_descs[m.desc or ""] = true
      end
      -- In insert/terminal/visual mode the same keys mean something else: get
      -- out of the mode, rather than tear the UI down under the cursor.
      H.ok(insert_descs["Switch to normal mode"], "<Esc> in insert mode only leaves insert mode")
      H.ok(insert_descs["Disabled"], "and <C-w> in insert mode is disabled rather than closing anything")

      keymaps.unset_close_ui_keymaps()
      H.eq(#vim.api.nvim_buf_get_keymap(ui_state.buffers.preview, "n"), 0, "and they come off again")

      -- A wiped buffer in the state must not break teardown.
      ui_state.buffers.prompt = { keywords = a }
      keymaps.set_prompt_keymaps()
      vim.api.nvim_buf_delete(a, { force = true })
      local ok_unset = pcall(keymaps.unset_prompt_keymaps)
      H.ok(ok_unset, "unsetting keymaps of an already-wiped buffer does not raise")

      for _, buf in ipairs({ b, ui_state.buffers.preview, ui_state.buffers.list }) do
        if buf and vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
      end
      ui_state.reset("buffers")

      -- The two global keymaps go through lib.nvim's registry.
      local registered = keymaps.set_user_keymaps({ open = "<leader>zo", close = "<leader>zc" }, { silent = true })
      H.eq(type(registered), "table", "registering the user keymaps returns the registry's report")
      local global = {}
      for _, m in ipairs(vim.api.nvim_get_keymap("n")) do
        global[m.lhs] = true
      end
      H.ok(
        global[vim.api.nvim_replace_termcodes("<leader>zo", true, false, true)] or global["\\zo"],
        "the open keymap is bound"
      )

      pcall(vim.keymap.del, "n", "<leader>zo")
      pcall(vim.keymap.del, "n", "<leader>zc")
    end)

    for k in pairs(ui_state.buffers) do
      ui_state.buffers[k] = nil
    end
    for k, v in pairs(saved_buffers) do
      ui_state.buffers[k] = v
    end
    config.options.prompt_keymaps = saved_prompt_keymaps
    if not ok then error(err, 0) end
  end

  ---------------------------------------------------------------------------
  -- autocmds
  ---------------------------------------------------------------------------
  do
    local autocmds = require("reposcope.bindings.autocmds")
    local closed = 0
    local on_close = function() closed = closed + 1 end

    autocmds.setup_ui_close(on_close)

    -- A Reposcope window closing takes the whole UI with it; anything else
    -- must be left alone, or `:q` in an unrelated window would tear down a
    -- picker the user is not even looking at.
    local reposcope_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(reposcope_buf, "reposcope://list")
    local other_buf = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(other_buf, "somewhere/else.lua")

    local original_buf = vim.api.nvim_get_current_buf()

    vim.api.nvim_set_current_buf(other_buf)
    vim.api.nvim_exec_autocmds("QuitPre", {})
    H.eq(closed, 0, "QuitPre in an unrelated window does not close the UI")

    vim.api.nvim_set_current_buf(reposcope_buf)
    vim.api.nvim_exec_autocmds("QuitPre", {})
    H.eq(closed, 1, "QuitPre in a reposcope:// window closes it")

    -- Registering twice must not leave two handlers behind, or `close_ui`
    -- would run once per registration.
    autocmds.setup_ui_close(on_close)
    vim.api.nvim_exec_autocmds("QuitPre", {})
    H.eq(closed, 2, "re-registering replaces the handler rather than adding a second one")

    autocmds.remove_ui_autocmd()
    vim.api.nvim_exec_autocmds("QuitPre", {})
    H.eq(closed, 2, "and removing it stops the UI from being closed at all")

    local ok_twice = pcall(autocmds.remove_ui_autocmd)
    H.ok(ok_twice, "removing it twice is harmless")

    vim.api.nvim_set_current_buf(original_buf)
    vim.api.nvim_buf_delete(reposcope_buf, { force = true })
    vim.api.nvim_buf_delete(other_buf, { force = true })
  end
end
