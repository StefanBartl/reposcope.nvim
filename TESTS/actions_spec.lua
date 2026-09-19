-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/actions_spec.lua — the user-facing actions: filtering, sorting, the
-- prompt's collect/search path, and the three read-only views.
--
-- The views are driven against a stubbed `ui.kit`, so what is asserted is the
-- content they would have rendered. Opening the float itself is ui.nvim's
-- job and is tested there.

return function(H)
  ---------------------------------------------------------------------------
  -- filter_repos
  ---------------------------------------------------------------------------
  local function with_filter(fn)
    local env = { displayed = 0, readme = 0, restored = 0, stored = nil, notes = {} }
    H.with_stubs({
      ["reposcope.cache.repository_cache"] = {
        get = function() return { total_count = #(env.items or {}), items = env.items or {} } end,
        set = function(response) env.stored = response end,
        restore_relevance_sorting = function() env.restored = env.restored + 1 end,
      },
      ["reposcope.controllers.list_controller"] = {
        display_repositories = function() env.displayed = env.displayed + 1 end,
      },
      ["reposcope.controllers.provider_controller"] = {
        fetch_readme_for_selected = function() env.readme = env.readme + 1 end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.ui.actions.filter_repos" }, function() fn(require("reposcope.ui.actions.filter_repos"), env) end)
  end

  with_filter(function(filter, env)
    env.items = {
      { name = "telescope.nvim", owner = { login = "nvim-telescope" }, description = "Find files with Lua" },
      { name = "fzf-lua", owner = { login = "ibhagwan" }, description = "Fuzzy finder" },
      { name = "nvim-cmp", owner = { login = "hrsh7th" }, description = "Completion engine" },
    }

    H.eq(filter.get_current_filter(), "", "no filter is active to begin with")

    filter.apply_filter("lua")
    -- The filter runs over the whole rendered line, so it matches an owner, a
    -- name or a description -- whichever the user was actually looking at.
    H.eq(#env.stored.items, 2, "a substring matches across name and description")
    H.eq(env.stored.total_count, 2, "and the count follows the filtered list")
    H.eq(filter.get_current_filter(), "lua", "the active filter is remembered, for the session file")
    H.eq(env.displayed, 1, "the list is redrawn")
    H.eq(env.readme, 1, "and the preview follows the new first entry")

    filter.apply_filter("NVIM-TELESCOPE")
    H.eq(#env.stored.items, 1, "matching is case-insensitive")
    H.eq(env.stored.items[1].name, "telescope.nvim", "and matches the owner as well as the name")

    filter.apply_filter("does-not-occur")
    H.eq(#env.stored.items, 0, "a filter that matches nothing yields an empty list, not the unfiltered one")

    -- A substring, deliberately, not a pattern: a user typing `nvim-cmp` must
    -- not have the `-` read as anything special.
    filter.apply_filter("nvim-cmp")
    H.eq(#env.stored.items, 1, "the match is a plain substring, so punctuation is literal")

    local before = env.restored
    filter.apply_filter("")
    H.eq(env.restored, before + 1, "an empty filter restores the original list instead of filtering to nothing")
    H.eq(filter.get_current_filter(), "", "and clears the remembered filter")
    H.contains(table.concat(env.notes, "\n"), "Filter cleared", "telling the user")

    filter.apply_filter(nil)
    H.eq(env.restored, before + 2, "a nil filter is the same as an empty one")
  end)

  ---------------------------------------------------------------------------
  -- sort_prompt
  ---------------------------------------------------------------------------
  local function with_sort(fn)
    local env = { displayed = 0, readme = 0, restored = 0, stored = nil, notes = {}, selected = nil }
    H.with_stubs({
      ["reposcope.cache.repository_cache"] = {
        get = function() return { total_count = #(env.items or {}), items = env.items or {} } end,
        set = function(response) env.stored = response end,
        restore_relevance_sorting = function() env.restored = env.restored + 1 end,
      },
      ["reposcope.controllers.list_controller"] = {
        display_repositories = function() env.displayed = env.displayed + 1 end,
      },
      ["reposcope.controllers.provider_controller"] = {
        fetch_readme_for_selected = function() env.readme = env.readme + 1 end,
      },
      ["ui.kit"] = {
        select = function(opts)
          env.selected = opts
          if env.choose then opts.on_select(env.choose) end
        end,
        input = function() end,
        viewer = function() end,
        note = function() end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.ui.actions.sort_prompt" }, function() fn(require("reposcope.ui.actions.sort_prompt"), env) end)
  end

  with_sort(function(sort, env)
    env.items = {
      { name = "zeta", owner = { login = "bravo" }, stargazers_count = 10 },
      { name = "alpha", owner = { login = "charlie" }, stargazers_count = 500 },
      { name = "mid", owner = { login = "alpha" } },
    }

    H.eq(sort.get_current_sort(), "relevance", "the list starts in relevance order")

    sort.apply_sort("name")
    H.eq(env.stored.items[1].name, "alpha", "`name` sorts by repository name, ascending")
    H.eq(env.stored.items[3].name, "zeta", "to the end")
    H.eq(sort.get_current_sort(), "name", "and the mode is remembered for the session file")
    H.eq(env.displayed, 1, "the list is redrawn")
    H.eq(env.readme, 1, "and the preview follows")

    sort.apply_sort("owner")
    H.eq(env.stored.items[1].owner.login, "alpha", "`owner` sorts by owner login")
    H.eq(env.stored.items[3].owner.login, "charlie", "ascending")

    sort.apply_sort("stars")
    H.eq(env.stored.items[1].stargazers_count, 500, "`stars` sorts by star count, descending")
    -- A repository with no star count must not sort above one with 10 stars,
    -- and must not crash the comparator either.
    H.eq(env.stored.items[3].name, "mid", "a missing star count counts as zero")

    -- Sorting must not reorder the cached list itself, or `relevance` would
    -- have nothing to restore.
    H.eq(env.items[1].name, "zeta", "the cached list is left in its own order")

    local before = env.restored
    sort.apply_sort("relevance")
    H.eq(env.restored, before + 1, "`relevance` restores the original response order")
    H.eq(sort.get_current_sort(), "relevance", "and the mode is recorded")
  end)

  with_sort(function(sort, env)
    env.items = {}
    sort.apply_sort("name")
    H.eq(env.stored, nil, "sorting an empty list stores nothing")
    H.eq(env.displayed, 0, "and redraws nothing")
    H.contains(table.concat(env.notes, "\n"), "No repositories to sort", "it says so instead")
  end)

  with_sort(function(sort, env)
    env.items = { { name = "a", owner = { login = "a" } } }
    sort.apply_sort("by-phase-of-the-moon")
    H.eq(env.stored, nil, "an unrecognised mode leaves the list untouched")
    H.eq(env.displayed, 1, "though the list is still redrawn")
  end)

  with_sort(function(sort, env)
    env.items = { { name = "b", owner = { login = "b" } }, { name = "a", owner = { login = "a" } } }
    env.choose = "name"
    sort.prompt_sort()
    H.eq(table.concat(env.selected.selection, ","), "name,owner,stars,relevance", "the menu offers all four modes")
    H.contains(env.selected.title, "Sort repositories", "under a title that says what it is")
    H.eq(env.stored.items[1].name, "a", "and choosing one applies it")
  end)

  ---------------------------------------------------------------------------
  -- prompt_config and prompt_input
  ---------------------------------------------------------------------------
  do
    local prompt_config = require("reposcope.ui.prompt.prompt_config")
    local saved_fields = vim.deepcopy(prompt_config.get_fields())

    local available = prompt_config.get_available_fields()
    H.ok(#available >= 5, "the whitelist of prompt fields is published")
    H.eq(available[1], "keywords", "sorted, so completion is stable")
    H.has(available, "prefix", "including the prefix pseudo-field")

    -- The whitelist is a copy: a caller appending to it (as `:Reposcope
    -- prompt`'s completion does, to add a usage hint) must not grow the
    -- module's own list.
    table.insert(available, "invented")
    H.eq(#prompt_config.get_available_fields(), #available - 1, "and handed out as a copy, not the live table")

    prompt_config.set_fields({ "keywords", "owner", "made-up", "keywords", "prefix" })
    local fields = prompt_config.get_fields()
    H.eq(
      table.concat(fields, ","),
      "prefix,keywords,owner",
      "invalid names are dropped, duplicates removed, prefix hoisted"
    )

    prompt_config.set_fields("not a table")
    H.eq(table.concat(prompt_config.get_fields(), ","), "prefix,keywords,owner", "a non-table argument changes nothing")

    prompt_config.set_fields({})
    H.eq(#prompt_config.get_fields(), 0, "an empty list is a legitimate configuration")

    -- A non-empty list where every entry is invalid (e.g. a single typo'd
    -- field name) is a real misconfiguration, not a deliberate empty prompt:
    -- it must not leave the prompt with no fields and no way to type a query
    -- (ERR-22).
    prompt_config.set_fields({ "keyword" })
    H.eq(
      table.concat(prompt_config.get_fields(), ","),
      "prefix,keywords,owner,language",
      "a wholly invalid non-empty list falls back to the defaults, not to nothing"
    )

    -- Geometry is recomputed from the current editor size, not captured once
    -- at load: a terminal resized mid-session must not leave the prompt at
    -- the old width.
    prompt_config.recompute()
    H.eq(type(prompt_config.width), "number", "the prompt geometry is recomputed on demand")
    H.eq(prompt_config.height, 3, "with the fixed prompt height")
    H.ok(
      prompt_config.prefix_win_width > prompt_config.prefix_len,
      "and the prefix window is wider than the prefix itself"
    )

    prompt_config.set_fields(saved_fields)
  end

  do
    local env = { searched = {}, recorded = {}, notes = {} }
    H.with_stubs({
      ["reposcope.controllers.provider_controller"] = {
        build_query = function(input)
          local parts = {}
          for k, v in pairs(input) do
            parts[#parts + 1] = k .. "=" .. v
          end
          table.sort(parts)
          return table.concat(parts, " ")
        end,
        fetch_repositories_and_display = function(query) env.searched[#env.searched + 1] = query end,
      },
      ["reposcope.state.query_stats"] = {
        record = function(query) env.recorded[#env.recorded + 1] = query end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.ui.prompt.prompt_input" }, function()
      local prompt_config = require("reposcope.ui.prompt.prompt_config")
      local prompt_state = require("reposcope.state.ui.prompt_state")
      local saved_fields = vim.deepcopy(prompt_config.get_fields())
      local saved_input = vim.deepcopy(prompt_state.input)

      local input_mod = require("reposcope.ui.prompt.prompt_input")

      prompt_config.set_fields({ "keywords", "owner", "language" })
      prompt_state.input = {}

      H.eq(next(input_mod.collect()), nil, "with nothing typed there is nothing to collect")
      H.eq(input_mod.get_last_query(), "", "and no query has been built yet")

      input_mod.on_enter()
      H.eq(#env.searched, 0, "pressing enter on an empty prompt searches nothing")
      H.contains(table.concat(env.notes, "\n"), "No input to search", "and says so")

      prompt_state.set_field_text("keywords", "telescope")
      prompt_state.set_field_text("owner", "")
      prompt_state.set_field_text("language", "lua")
      -- A field the user cleared must not become an empty qualifier in the
      -- query.
      local collected = input_mod.collect()
      H.eq(collected.keywords, "telescope", "a filled field is collected")
      H.eq(collected.language, "lua", "for each of them")
      H.eq(collected.owner, nil, "and an emptied field is left out entirely")

      -- A field that is no longer visible must not leak into the query.
      prompt_state.set_field_text("topic", "hidden")
      H.eq(input_mod.collect().topic, nil, "text from a field that is not on screen is ignored")

      input_mod.on_enter()
      H.eq(#env.searched, 1, "a non-empty prompt searches")
      H.eq(env.searched[1], "keywords=telescope language=lua", "with the provider-built query")
      H.eq(input_mod.get_last_query(), "keywords=telescope language=lua", "which is remembered for the session file")
      H.eq(env.recorded[1], env.searched[1], "and recorded in the query-frequency counters")

      prompt_config.set_fields(saved_fields)
      prompt_state.input = saved_input
    end)
  end

  ---------------------------------------------------------------------------
  -- prompt_reload
  ---------------------------------------------------------------------------
  do
    local env = { fields = nil, notes = {}, closed = 0, opened = 0 }
    H.with_stubs({
      ["reposcope.ui.prompt.prompt_config"] = {
        set_fields = function(f) env.fields = f end,
        get_fields = function() return env.fields or {} end,
        get_available_fields = function() return {} end,
        recompute = function() end,
      },
      ["reposcope.init"] = {
        close_ui = function() env.closed = env.closed + 1 end,
        open_ui = function() env.opened = env.opened + 1 end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.ui.actions.prompt_reload" }, function()
      local reload = require("reposcope.ui.actions.prompt_reload")

      reload.reload_prompt({ "prefix", "keywords" })
      H.eq(table.concat(env.fields, ","), "prefix,keywords", "the named fields are applied")
      H.eq(env.closed, 1, "and the UI is torn down to pick them up")
      -- The reopen is deferred, to let the teardown finish first.
      vim.wait(400, function() return env.opened > 0 end)
      H.eq(env.opened, 1, "then reopened")

      reload.reload_prompt({})
      H.eq(table.concat(env.fields, ","), "keywords,owner,language", "an empty list falls back to the default three")
      H.contains(table.concat(env.notes, "\n"), "Using default fields", "and says so")

      reload.reload_prompt(nil)
      H.eq(table.concat(env.fields, ","), "keywords,owner,language", "as does no list at all")
      vim.wait(400)
    end)
  end

  ---------------------------------------------------------------------------
  -- The read-only views
  ---------------------------------------------------------------------------
  ---@param stubs table
  ---@param module string
  ---@param fn fun(view: table, shown: table[]): nil
  local function with_view(stubs, module, fn)
    local shown = {}
    local kit_stub = {
      viewer = function(opts) shown[#shown + 1] = opts end,
      input = function(opts) shown[#shown + 1] = opts end,
      select = function(opts) shown[#shown + 1] = opts end,
      note = function(opts) shown[#shown + 1] = opts end,
    }
    local all = vim.tbl_extend("force", { ["ui.kit"] = kit_stub }, stubs)
    H.with_stubs(all, { module }, function() fn(require(module), shown, kit_stub) end)
  end

  -- favorites_view
  with_view(
    {
      ["reposcope.state.favorites_state"] = { list = function() return {} end },
    },
    "reposcope.ui.actions.favorites_view",
    function(view, shown)
      view.show()
      local text = table.concat(shown[1].lines, "\n")
      H.contains(text, "No favorites yet", "an empty favourites list says so")
      -- The empty state has to name the way to leave it, or the feature is
      -- undiscoverable.
      H.contains(text, "toggle_favorite", "and names the keymap that adds one")
      H.contains(shown[1].title, "Favorites", "under a title")
    end
  )

  with_view(
    {
      ["reposcope.state.favorites_state"] = {
        list = function()
          return {
            {
              owner = "nvim-telescope",
              name = "telescope.nvim",
              description = "Find files",
              html_url = "https://github.com/nvim-telescope/telescope.nvim",
              stargazers_count = 15000,
            },
            { owner = "someone", name = "bare", description = "", html_url = "https://example.invalid/bare" },
          }
        end,
      },
    },
    "reposcope.ui.actions.favorites_view",
    function(view, shown)
      view.show()
      local text = table.concat(shown[1].lines, "\n")
      H.contains(text, "nvim-telescope/telescope.nvim", "each favourite is listed as owner/name")
      H.contains(text, "Find files", "with its description")
      H.contains(text, "15000", "its star count")
      H.contains(text, "https://github.com/nvim-telescope/telescope.nvim", "and its URL")
      H.contains(text, "No description", "a favourite without a description gets a placeholder")
      H.contains(text, "https://example.invalid/bare", "and one without stars still shows its URL")
      H.contains(text, "close", "the view says how to close itself")
      H.ok(shown[1].width > 20, "the window is sized to the content")
      H.eq(shown[1].filetype, "reposcope-favorites", "with its own filetype, so it can be styled")
    end
  )

  -- help_view
  with_view({}, "reposcope.ui.actions.help_view", function(view, shown)
    view.show()
    local text = table.concat(shown[1].lines, "\n")
    H.contains(text, "Global", "the cheatsheet has a global section")
    H.contains(text, "Open Reposcope", "naming the open keymap")
    H.contains(text, "Prompt", "a prompt section")
    H.contains(text, "Confirm prompt input", "built from the same descriptions the keymaps carry")
    H.contains(text, "Navigate list up", "for every active action")
  end)

  -- filter_prompt
  with_view(
    {
      ["reposcope.ui.actions.filter_repos"] = {
        apply_filter = function(text) _G.__reposcope_test_filter = text end,
        get_current_filter = function() return "" end,
      },
    },
    "reposcope.ui.actions.filter_prompt",
    function(view, shown)
      _G.__reposcope_test_filter = nil
      view.prompt_filter()
      H.contains(shown[1].title, "Filter Repositories", "the input announces what it filters")

      shown[1].on_submit("lua")
      H.eq(
        _G.__reposcope_test_filter,
        "lua",
        "submitting applies the filter through the same path as `:Reposcope filter`"
      )

      _G.__reposcope_test_filter = nil
      shown[1].on_submit("")
      H.eq(_G.__reposcope_test_filter, nil, "an empty submission does nothing -- it is a cancel, not a reset")
      shown[1].on_submit(nil)
      H.eq(_G.__reposcope_test_filter, nil, "and neither does a cancelled one")
      _G.__reposcope_test_filter = nil
    end
  )
end
