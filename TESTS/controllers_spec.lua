-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/controllers_spec.lua — the three provider-agnostic controllers that
-- sit between the cache and the windows: the list renderer, the post-search
-- UI loader (including the README pre-cache), and the favourites start view.
--
-- Every window-touching collaborator is stubbed in `package.loaded` before
-- the controller is required, so the assertions are about the lines and the
-- calls that would have been made.

return function(H)
  ---------------------------------------------------------------------------
  -- list_controller: cache -> display lines
  ---------------------------------------------------------------------------
  local function with_list_controller(env, fn)
    env.displayed = nil
    env.cleared = 0
    env.notes = {}

    H.with_stubs(
      {
        ["reposcope.ui.list.list_window"] = {
          open_window = function() return env.window_opens ~= false end,
          highlighted_line = 1,
        },
        ["reposcope.ui.list.list_manager"] = {
          clear_list = function() env.cleared = env.cleared + 1 end,
          show_list = function(lines) env.displayed = lines end,
          reset_selected_line = function() end,
        },
        ["reposcope.ui.list.list_config"] = { width = env.width or 60, recompute = function() end },
        ["reposcope.cache.repository_cache"] = {
          get = function() return env.response end,
        },
        ["reposcope.utils.debug"] = {
          notify = function(msg) env.notes[#env.notes + 1] = msg end,
          is_dev_mode = function() return false end,
          debugf = function() end,
          options = { dev_mode = false },
        },
      },
      { "reposcope.controllers.list_controller" },
      function() fn(require("reposcope.controllers.list_controller"), env) end
    )
  end

  with_list_controller({ window_opens = false, response = { items = {} } }, function(controller, env)
    controller.display_repositories()
    H.eq(env.displayed, nil, "a list window that refuses to open means nothing is displayed")
    H.contains(env.notes[1], "List window initialization failed", "and the failure is reported")
  end)

  with_list_controller({ response = nil }, function(controller, env)
    controller.display_repositories()
    H.eq(env.cleared, 1, "with no cached response the list is cleared")
    H.eq(env.displayed, nil, "rather than displaying anything")
  end)

  with_list_controller({ response = { total_count = 0 } }, function(controller, env)
    controller.display_repositories()
    H.eq(env.cleared, 1, "a response with no items table is the same non-event")
  end)

  with_list_controller({ response = { items = {} } }, function(controller, env)
    controller.display_repositories()
    H.eq(#env.displayed, 0, "an empty result set displays zero lines")
    H.eq(env.cleared, 0, "without being treated as an error")
  end)

  with_list_controller({
    response = {
      items = {
        { name = "telescope.nvim", owner = { login = "nvim-telescope" }, description = "Find files" },
        { name = "fzf-lua", owner = { login = "ibhagwan" }, description = "Fuzzy finder" },
      },
    },
  }, function(controller, env)
    controller.display_repositories()
    H.eq(#env.displayed, 2, "one line per repository")
    H.eq(env.displayed[1], "nvim-telescope/telescope.nvim: Find files", "in the `owner/name: description` shape")
    H.eq(env.displayed[2], "ibhagwan/fzf-lua: Fuzzy finder", "for each of them")
  end)

  -- The line has to fit the list window, or the buffer scrolls sideways.
  with_list_controller({
    width = 20,
    response = { items = { { name = "n", owner = { login = "o" }, description = string.rep("x", 200) } } },
  }, function(controller, env)
    controller.display_repositories()
    H.eq(#env.displayed[1], 19, "a long line is cut to the list width")
    H.contains(env.displayed[1], "...", "with an ellipsis")
  end)

  -- Fields the API may omit, or send as JSON null (which decodes to vim.NIL).
  with_list_controller({
    response = {
      items = {
        { name = "bare" },
        { owner = { login = "someone" } },
        { name = "nulled", owner = { login = "o" }, description = vim.NIL },
      },
    },
  }, function(controller, env)
    controller.display_repositories()
    H.eq(env.displayed[1], "Unknown/bare: No description", "a missing owner and description both get placeholders")
    H.eq(env.displayed[2], "someone/No name: No description", "as does a missing name")
    H.eq(
      env.displayed[3],
      "o/nulled: No description",
      "and a JSON null description never reaches the buffer as userdata"
    )
    H.excludes(table.concat(env.displayed, "\n"), "userdata", "nothing leaks a raw userdata into the list")
  end)

  ---------------------------------------------------------------------------
  -- repository_ui_loader: what happens right after a search returns
  ---------------------------------------------------------------------------
  local function with_ui_loader(env, fn)
    env.reset = 0
    env.displayed = 0
    env.readme_fetches = 0
    env.prefetched = {}
    env.notes = {}

    H.with_stubs({
      ["reposcope.ui.list.list_manager"] = {
        reset_selected_line = function() env.reset = env.reset + 1 end,
        clear_list = function() end,
        show_list = function() end,
      },
      ["reposcope.controllers.list_controller"] = {
        display_repositories = function() env.displayed = env.displayed + 1 end,
      },
      ["reposcope.controllers.provider_controller"] = {
        fetch_readme_for_selected = function() env.readme_fetches = env.readme_fetches + 1 end,
        prefetch_readme = function(repo) env.prefetched[#env.prefetched + 1] = repo.name end,
      },
      ["reposcope.cache.repository_cache"] = {
        get = function() return { items = env.items or {} } end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.controllers.repository_ui_loader" }, function()
      local config = require("reposcope.config")
      local saved = config.options.readme_precache_count
      if env.precache ~= nil then config.options.readme_precache_count = env.precache end

      local ui_state = require("reposcope.state.ui.ui_state")
      local saved_buf = ui_state.buffers.list
      ui_state.buffers.list = env.list_buf

      local ok, err = pcall(fn, require("reposcope.controllers.repository_ui_loader"), env)

      ui_state.buffers.list = saved_buf
      config.options.readme_precache_count = saved
      if not ok then error(err, 0) end
    end)
  end

  do
    local buf = vim.api.nvim_create_buf(false, true)

    with_ui_loader({
      list_buf = buf,
      precache = 3,
      items = { { name = "first" }, { name = "second" }, { name = "third" }, { name = "fourth" } },
    }, function(loader, env)
      loader.load_ui_after_fetch()
      -- The README trigger is deferred by 100ms so the list is on screen first.
      vim.wait(500, function() return env.readme_fetches > 0 end)

      H.eq(env.reset, 1, "the selection is reset to the top")
      H.eq(env.displayed, 1, "the list is drawn")
      H.eq(
        require("reposcope.state.ui.ui_state").list.last_selected_line,
        1,
        "and the first entry becomes the selection"
      )
      H.eq(env.readme_fetches, 1, "whose README is fetched through the normal selected-line path")

      -- Entry 1 is already covered by that fetch, so the pre-cache starts at 2
      -- and stops at the configured count.
      H.eq(#env.prefetched, 2, "the remaining top results are pre-cached")
      H.eq(env.prefetched[1], "second", "starting at the second entry")
      H.eq(env.prefetched[2], "third", "and stopping at the configured count")
    end)

    with_ui_loader({ list_buf = buf, precache = 1, items = { { name = "a" }, { name = "b" } } }, function(loader, env)
      loader.load_ui_after_fetch()
      vim.wait(500, function() return env.readme_fetches > 0 end)
      H.eq(#env.prefetched, 0, "a pre-cache count of 1 covers only the entry that is fetched anyway")
    end)

    with_ui_loader({ list_buf = buf, precache = 0, items = { { name = "a" }, { name = "b" } } }, function(loader, env)
      loader.load_ui_after_fetch()
      vim.wait(500, function() return env.readme_fetches > 0 end)
      H.eq(#env.prefetched, 0, "and zero disables it entirely")
    end)

    -- Fewer results than the configured count: the loop must stop at the data.
    with_ui_loader({ list_buf = buf, precache = 10, items = { { name = "a" }, { name = "b" } } }, function(loader, env)
      loader.load_ui_after_fetch()
      vim.wait(500, function() return env.readme_fetches > 0 end)
      H.eq(#env.prefetched, 1, "a pre-cache count larger than the result set stops at the last result")
    end)

    -- The UI can be gone by the time the deferred callback runs (the user
    -- closed it during the search).
    with_ui_loader({ list_buf = nil, precache = 5, items = { { name = "a" } } }, function(loader, env)
      loader.load_ui_after_fetch()
      -- Same 100ms deferral as above; the only observable outcome on this
      -- branch is the note, so that is what to wait for, not a stopwatch.
      vim.wait(500, function() return #env.notes > 0 end)
      H.eq(env.readme_fetches, 0, "with the list window gone, no README is fetched")
      H.eq(#env.prefetched, 0, "and nothing is pre-cached")
      H.contains(table.concat(env.notes, "\n"), "List buffer is not available", "the reason is reported")
    end)

    vim.api.nvim_buf_delete(buf, { force = true })
  end

  ---------------------------------------------------------------------------
  -- start_view_controller: favourites as the opening screen
  ---------------------------------------------------------------------------
  local function with_start_view(favorites, fn)
    local env = { cached = nil, warmed = {}, displayed = 0, readme_fetches = 0, notes = {} }

    H.with_stubs(
      {
        ["reposcope.state.favorites_state"] = {
          list = function() return favorites end,
        },
        ["reposcope.cache.repository_cache"] = {
          set = function(response, is_original) env.cached = { response = response, is_original = is_original } end,
        },
        ["reposcope.cache.readme_cache"] = {
          set_ram = function(o, r, c) env.warmed[#env.warmed + 1] = { owner = o, repo = r, content = c } end,
        },
        ["reposcope.controllers.list_controller"] = {
          display_repositories = function() env.displayed = env.displayed + 1 end,
        },
        ["reposcope.controllers.provider_controller"] = {
          fetch_readme_for_selected = function() env.readme_fetches = env.readme_fetches + 1 end,
        },
        ["reposcope.utils.debug"] = {
          notify = function(msg) env.notes[#env.notes + 1] = msg end,
          is_dev_mode = function() return false end,
          debugf = function() end,
          options = { dev_mode = false },
        },
      },
      { "reposcope.controllers.start_view_controller" },
      function() fn(require("reposcope.controllers.start_view_controller"), env) end
    )
  end

  with_start_view({}, function(controller, env)
    H.falsy(controller.show_favorites_if_any(), "with no favourites the start view declines")
    H.eq(env.cached, nil, "and touches nothing -- the caller falls back to an empty prompt")
    H.eq(env.displayed, 0, "including the list")
  end)

  with_start_view({
    {
      owner = "nvim-telescope",
      name = "telescope.nvim",
      description = "Find files",
      html_url = "https://github.com/nvim-telescope/telescope.nvim",
      default_branch = "master",
      stargazers_count = 15000,
      readme = "# Telescope",
    },
    { owner = "ibhagwan", name = "fzf-lua", description = "Fuzzy" },
  }, function(controller, env)
    H.ok(controller.show_favorites_if_any(), "with favourites the start view takes over")

    -- Favourites are fed through the same display path a real search result
    -- takes, so navigation/sorting/filtering all work unchanged.
    H.eq(env.cached.response.total_count, 2, "both favourites become a result set")
    H.eq(env.cached.is_original, true, "marked as the original order, so `sort relevance` can restore it")
    local first = env.cached.response.items[1]
    H.eq(first.name, "telescope.nvim", "the flat favourite is expanded back into a Repository")
    H.eq(first.owner.login, "nvim-telescope", "with a nested owner table, the shape the rest of the plugin expects")
    H.eq(first.stargazers_count, 15000, "and the snapshotted metadata")

    -- A favourite that was snapshotted with its README needs no fetch at all.
    H.eq(#env.warmed, 1, "only the favourite that carries a README warms the cache")
    H.eq(env.warmed[1].content, "# Telescope", "with the snapshotted content")
    H.eq(env.warmed[1].repo, "telescope.nvim", "for the right repository")

    H.eq(env.displayed, 1, "the list is drawn once")
    H.eq(env.readme_fetches, 1, "and the preview is primed for the first entry")
    H.contains(env.notes[#env.notes], "Showing 2 favorites", "the user is told how many, in the plural")
  end)

  with_start_view({ { owner = "o", name = "r" } }, function(controller, env)
    controller.show_favorites_if_any()
    H.contains(env.notes[#env.notes], "Showing 1 favorite", "and in the singular for exactly one")
    H.excludes(env.notes[#env.notes], "favorites", "without a stray plural s")
  end)
end
