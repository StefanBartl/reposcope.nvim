-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/provider_controller_spec.lua — the dispatcher every feature goes
-- through to reach "the current provider".
--
-- The three provider entrypoints are replaced in `package.loaded` before the
-- controller is required: it builds its `providers` table at load time, so a
-- later patch would be invisible.

return function(H)
  ---@param fn fun(controller: table, env: table, config: table): nil
  local function with_controller(fn)
    local env = { calls = {}, notes = {} }

    local function entry(name, overrides)
      local base = {
        readme_manager = {
          fetch_for_selected = function(uuid) env.calls[#env.calls + 1] = { p = name, what = "readme", uuid = uuid } end,
          prefetch = function(repo) env.calls[#env.calls + 1] = { p = name, what = "prefetch", repo = repo } end,
        },
        repo_fetcher = {
          refresh_results = function(query, uuid, on_success)
            env.calls[#env.calls + 1] =
              { p = name, what = "search", query = query, uuid = uuid, on_success = on_success }
          end,
          fetch = function() end,
        },
        cloner = {
          clone = function(path, uuid)
            env.calls[#env.calls + 1] = { p = name, what = "clone", path = path, uuid = uuid }
          end,
        },
        query_builder = {
          build = function(input) return name .. ":" .. (input.keywords or "") end,
        },
      }
      return vim.tbl_deep_extend("force", base, overrides or {})
    end

    H.with_stubs({
      ["reposcope.providers.github.entrypoint"] = entry("github"),
      ["reposcope.providers.gitlab.entrypoint"] = entry("gitlab"),
      ["reposcope.providers.codeberg.entrypoint"] = entry("codeberg"),
      ["reposcope.cache.repository_cache"] = {
        clear_relevance_result = function() env.calls[#env.calls + 1] = { what = "clear_relevance" } end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.controllers.provider_controller" }, function()
      local config = require("reposcope.config")
      local saved = config.options.provider
      local ok, err = pcall(fn, require("reposcope.controllers.provider_controller"), env, config)
      config.options.provider = saved
      if not ok then error(err, 0) end
    end)
  end

  ---------------------------------------------------------------------------
  -- The registry
  ---------------------------------------------------------------------------
  with_controller(function(controller, _env, config)
    local names = controller.get_registered_providers()
    H.eq(#names, 3, "three providers are registered")
    -- Sorted, because this list is printed by `:Reposcope providers` and used
    -- in the "unknown provider" message; an unordered `tbl_keys` would make
    -- both reshuffle between runs.
    H.eq(table.concat(names, ","), "codeberg,github,gitlab", "in a stable, sorted order")

    config.options.provider = "gitlab"
    H.eq(controller.get_active_provider(), "gitlab", "the active provider comes from the configuration")
  end)

  ---------------------------------------------------------------------------
  -- An unknown provider is reported once per dispatch, never dispatched
  ---------------------------------------------------------------------------
  with_controller(function(controller, env, config)
    config.options.provider = "sourcehut"

    H.eq(controller.build_query({ keywords = "x" }), "", "building a query yields an empty string")
    H.contains(env.notes[1], "Unknown provider 'sourcehut'", "with the configured name in the message")
    H.contains(env.notes[1], "codeberg, github, gitlab", "and the list of ones that do exist")

    controller.search_repositories("x")
    controller.prefetch_readme({ name = "r", owner = { login = "o" } })
    for _, call in ipairs(env.calls) do
      H.ok(call.what == "clear_relevance" or false, "nothing was dispatched to a provider")
    end
  end)

  ---------------------------------------------------------------------------
  -- Query building is the provider's own
  ---------------------------------------------------------------------------
  with_controller(function(controller, _env, config)
    config.options.provider = "github"
    H.eq(controller.build_query({ keywords = "telescope" }), "github:telescope", "the active provider builds the query")
    config.options.provider = "codeberg"
    H.eq(
      controller.build_query({ keywords = "forgejo" }),
      "codeberg:forgejo",
      "and a different one builds it differently"
    )
  end)

  ---------------------------------------------------------------------------
  -- Searching
  ---------------------------------------------------------------------------
  with_controller(function(controller, env, config)
    config.options.provider = "gitlab"
    local continued = false
    controller.search_repositories("runner", function() continued = true end)

    -- The previous relevance snapshot has to go *before* the new search, or
    -- `:Reposcope sort relevance` would restore the previous query's results.
    H.eq(env.calls[1].what, "clear_relevance", "the previous relevance snapshot is dropped first")
    H.eq(env.calls[2].what, "search", "then the search is dispatched")
    H.eq(env.calls[2].p, "gitlab", "to the active provider")
    H.eq(env.calls[2].query, "runner", "with the query")
    H.ok(type(env.calls[2].uuid) == "string" and #env.calls[2].uuid > 0, "and a freshly registered UUID")
    H.ok(
      require("reposcope.state.requests_state").is_registered(env.calls[2].uuid),
      "which the request state knows about"
    )

    env.calls[2].on_success()
    H.ok(continued, "the caller's continuation is handed through to the fetcher")

    require("reposcope.state.requests_state").clear_all_requests()
  end)

  ---------------------------------------------------------------------------
  -- Pre-caching
  ---------------------------------------------------------------------------
  with_controller(function(controller, env, config)
    config.options.provider = "github"
    local repo = { name = "telescope.nvim", owner = { login = "nvim-telescope" } }
    controller.prefetch_readme(repo)
    H.eq(env.calls[1].what, "prefetch", "a pre-cache is dispatched")
    H.eq(env.calls[1].repo.name, "telescope.nvim", "for the given repository")
  end)

  -- A provider whose README manager has no `prefetch` must be skipped rather
  -- than crashed into: the feature was added after the managers existed.
  do
    H.with_stubs({
      ["reposcope.providers.github.entrypoint"] = {
        readme_manager = { fetch_for_selected = function() end },
        repo_fetcher = { refresh_results = function() end },
        cloner = { clone = function() end },
        query_builder = { build = function() return "" end },
      },
      ["reposcope.providers.gitlab.entrypoint"] = require("reposcope.providers.gitlab.entrypoint"),
      ["reposcope.providers.codeberg.entrypoint"] = require("reposcope.providers.codeberg.entrypoint"),
    }, { "reposcope.controllers.provider_controller" }, function()
      local config = require("reposcope.config")
      local saved = config.options.provider
      config.options.provider = "github"
      local ok = pcall(
        function()
          require("reposcope.controllers.provider_controller").prefetch_readme({ name = "r", owner = { login = "o" } })
        end
      )
      H.ok(ok, "a provider without a prefetch implementation is a silent no-op, not an error")
      config.options.provider = saved
    end)
  end

  ---------------------------------------------------------------------------
  -- README fetches are debounced, and the skipped ones are counted
  ---------------------------------------------------------------------------
  with_controller(function(controller, env, config)
    config.options.provider = "github"

    local before = controller.get_skipped_fetches()

    -- Three rapid calls, as list navigation produces: only the last survives.
    controller.fetch_readme_for_selected()
    controller.fetch_readme_for_selected()
    controller.fetch_readme_for_selected()

    local readme_calls = 0
    vim.wait(500, function()
      readme_calls = 0
      for _, call in ipairs(env.calls) do
        if call.what == "readme" then readme_calls = readme_calls + 1 end
      end
      return readme_calls > 0
    end)

    H.eq(readme_calls, 1, "three rapid navigations collapse into one README fetch")
    H.eq(controller.get_skipped_fetches() - before, 2, "and the two that were superseded are counted")

    -- Each call still registers its own UUID, so the manager's duplicate
    -- guard has something to gate on.
    for _, call in ipairs(env.calls) do
      if call.what == "readme" then
        H.ok(
          require("reposcope.state.requests_state").is_registered(call.uuid),
          "the surviving fetch carries a registered UUID"
        )
      end
    end

    require("reposcope.state.requests_state").clear_all_requests()
  end)

  ---------------------------------------------------------------------------
  -- start_clone
  ---------------------------------------------------------------------------
  do
    -- `vim.ui.input` is captured into a file-local when the controller loads,
    -- so the double has to be in place before the `require` inside
    -- `with_controller` -- not after it.
    local original_input = vim.ui.input
    local prompts = {}
    local answer = "/tmp/clones"
    ---@diagnostic disable-next-line: duplicate-set-field
    vim.ui.input = function(opts, on_confirm)
      prompts[#prompts + 1] = opts
      on_confirm(answer)
    end

    local ok, err = pcall(function()
      with_controller(function(controller, env, config)
        config.options.provider = "github"
        controller.start_clone()
        vim.wait(200, function()
          for _, call in ipairs(env.calls) do
            if call.what == "clone" then return true end
          end
          return false
        end)

        H.eq(prompts[1].prompt, "Set clone path: ", "the user is asked where to clone")
        -- `dir`, not `file`: a clone target can only be a directory, and file
        -- completion would offer candidates that cannot be the answer.
        H.eq(prompts[1].completion, "dir", "with directory completion")
        H.ok(
          type(prompts[1].default) == "string" and prompts[1].default ~= "",
          "and the configured clone directory prefilled"
        )

        local cloned
        for _, call in ipairs(env.calls) do
          if call.what == "clone" then cloned = call end
        end
        H.ok(cloned, "the clone is dispatched")
        H.eq(cloned.p, "github", "to the active provider")
        H.eq(cloned.path, "/tmp/clones", "with the entered path")
        H.ok(require("reposcope.state.requests_state").is_registered(cloned.uuid), "and a registered UUID")

        -- Cancelling the prompt must not start anything.
        local before = #env.calls
        answer = nil
        controller.start_clone()
        vim.wait(100)
        H.eq(#env.calls, before, "cancelling the prompt dispatches nothing")
        H.contains(env.notes[#env.notes], "Cloning canceled", "and says so")
      end)
    end)

    vim.ui.input = original_input
    require("reposcope.state.requests_state").clear_all_requests()
    if not ok then error(err, 0) end
  end
end
