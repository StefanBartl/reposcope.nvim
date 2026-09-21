-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/repository_manager_spec.lua — the three search managers.
--
-- Thin by design: they own the request lifecycle (register/active gating) and
-- the "what happens when the search fails" decision, and delegate everything
-- else. Fetcher, UI loader, list and preview are all stubbed in
-- `package.loaded` before the manager is required.

return function(H)
  local MANAGERS = {
    { name = "github", module = "reposcope.providers.github.repositories.repository_manager" },
    { name = "gitlab", module = "reposcope.providers.gitlab.repositories.repository_manager" },
    { name = "codeberg", module = "reposcope.providers.codeberg.repositories.repository_manager" },
  }

  local function with_manager(provider, module, fn)
    local env = { fetches = {}, cleared = {}, loaded = 0, notes = {}, outcome = nil }

    local stubs = {
      ["reposcope.providers." .. provider .. ".repositories.repository_fetcher"] = {
        fetch_repositories = function(query, on_success, on_failure)
          env.fetches[#env.fetches + 1] = { query = query }
          if env.outcome == "success" then
            on_success()
          elseif env.outcome == "failure" then
            on_failure()
          end
        end,
        build_url = function(q) return "https://example.invalid/?q=" .. q end,
      },
      ["reposcope.controllers.repository_ui_loader"] = {
        load_ui_after_fetch = function() env.loaded = env.loaded + 1 end,
      },
      ["reposcope.ui.list.list_manager"] = {
        clear_list = function() env.cleared[#env.cleared + 1] = "list" end,
        show_list = function() end,
        reset_selected_line = function() end,
      },
      ["reposcope.ui.preview.preview_manager"] = {
        clear_preview = function() env.cleared[#env.cleared + 1] = "preview" end,
        update_preview = function() end,
        inject_content = function() end,
      },
      ["reposcope.cache.repository_cache"] = {
        clear = function() env.cleared[#env.cleared + 1] = "cache" end,
        get = function() return { total_count = 0, items = {}, list = {} } end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }

    H.with_stubs(stubs, { module }, function()
      local request_state = require("reposcope.state.requests_state")
      request_state.clear_all_requests()
      fn(require(module), env, request_state)
      request_state.clear_all_requests()
    end)
  end

  for _, m in ipairs(MANAGERS) do
    for _, entry in ipairs({ "fetch", "refresh_results" }) do
      -----------------------------------------------------------------------
      -- Gating
      -----------------------------------------------------------------------
      with_manager(m.name, m.module, function(manager, env, request_state)
        manager[entry]("nvim", "unknown-uuid")
        H.eq(#env.fetches, 0, ("%s.%s: an unregistered UUID never searches"):format(m.name, entry))
        H.contains(env.notes[1], "UUID not registered", "and says why")

        request_state.register_request("a")
        request_state.start_request("a")
        manager[entry]("nvim", "a")
        H.eq(#env.fetches, 0, "an already-active UUID is skipped -- this is the duplicate-search guard")
        H.contains(env.notes[2], "Request already active", "and says why")
      end)

      -----------------------------------------------------------------------
      -- The happy path
      -----------------------------------------------------------------------
      with_manager(m.name, m.module, function(manager, env, request_state)
        request_state.register_request("b")
        env.outcome = "success"

        local succeeded = false
        manager[entry]("nvim plugin", "b", function() succeeded = true end)

        H.eq(#env.fetches, 1, ("%s.%s: one search"):format(m.name, entry))
        H.eq(env.fetches[1].query, "nvim plugin", "with the caller's query, unmodified")
        H.ok(request_state.is_request_active("b"), "the UUID is marked active before the search runs")
        H.ok(succeeded, "the success callback fires")
        H.eq(#env.cleared, 0, "and nothing is cleared")

        -- Documented, not a defect: neither entry point ever calls
        -- `end_request`. The UUID stays in `requests_state` for the rest of
        -- the session -- harmless, because `provider_controller` generates a
        -- fresh one per search, but it does mean the table only grows. The
        -- README managers next door *do* close their requests.
        H.ok(request_state.is_registered("b"), "the request is deliberately never closed by this manager")
      end)

      -----------------------------------------------------------------------
      -- Failure: caller's handler wins, otherwise the UI is emptied
      -----------------------------------------------------------------------
      with_manager(m.name, m.module, function(manager, env, request_state)
        request_state.register_request("c")
        env.outcome = "failure"

        local failed = false
        manager[entry]("nvim", "c", nil, function() failed = true end)
        H.ok(failed, ("%s.%s: a caller-supplied failure handler is used"):format(m.name, entry))
        H.eq(#env.cleared, 0, "and the default teardown is not run on top of it")
      end)

      with_manager(m.name, m.module, function(manager, env, request_state)
        request_state.register_request("d")
        env.outcome = "failure"

        manager[entry]("nvim", "d")

        local cleared = {}
        for _, what in ipairs(env.cleared) do
          cleared[what] = true
        end
        H.ok(cleared.cache, ("%s.%s: without a handler, the stale result is dropped"):format(m.name, entry))
        H.ok(cleared.list, "the list is emptied")
        H.ok(cleared.preview, "and so is the preview -- no half-state left on screen")
      end)
    end

    -------------------------------------------------------------------------
    -- Only `refresh_results` rebuilds the UI
    -------------------------------------------------------------------------
    with_manager(m.name, m.module, function(manager, env, request_state)
      request_state.register_request("e")
      env.outcome = "success"
      manager.fetch("nvim", "e")
      H.eq(env.loaded, 0, m.name .. ": `fetch` is the headless entry point -- it never loads the UI")

      request_state.register_request("f")
      manager.refresh_results("nvim", "f")
      H.eq(env.loaded, 1, "`refresh_results` does")
    end)

    -- Ordering matters: the list has to exist before a caller's continuation
    -- (session restore re-applies filter and sort there) runs.
    with_manager(m.name, m.module, function(manager, env, request_state)
      request_state.register_request("g")
      env.outcome = "success"
      local order = {}
      env.loaded = 0
      manager.refresh_results("nvim", "g", function() order[#order + 1] = "callback" end)
      H.eq(env.loaded, 1, m.name .. ": the UI loader ran")
      H.eq(order[1], "callback", "and the caller's continuation ran after it")
    end)
  end

  ---------------------------------------------------------------------------
  -- Every provider entrypoint exposes the same four members
  ---------------------------------------------------------------------------
  for _, provider in ipairs({ "github", "gitlab", "codeberg" }) do
    local entry = require("reposcope.providers." .. provider .. ".entrypoint")
    H.ok(type(entry.readme_manager) == "table", provider .. " exposes a readme_manager")
    H.ok(type(entry.repo_fetcher) == "table", provider .. " exposes a repo_fetcher")
    H.ok(type(entry.cloner) == "table", provider .. " exposes a cloner")
    H.ok(type(entry.query_builder) == "table", provider .. " exposes a query_builder")
    H.ok(type(entry.repo_fetcher.refresh_results) == "function", provider .. "'s fetcher can search and display")
    H.ok(
      type(entry.readme_manager.fetch_for_selected) == "function",
      provider .. "'s readme manager answers for a selection"
    )
    H.ok(type(entry.readme_manager.prefetch) == "function", provider .. "'s readme manager can pre-cache")
    H.ok(type(entry.cloner.clone) == "function", provider .. "'s cloner can clone")
    H.ok(type(entry.query_builder.build) == "function", provider .. "'s query builder can build")
  end
end
