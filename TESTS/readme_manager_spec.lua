-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/readme_manager_spec.lua — the three README managers.
--
-- These are the modules that decide *whether* a request happens at all: they
-- gate on the request-state UUID, on cache freshness, and (GitHub only) on
-- whether the raw host can possibly answer. The three are near-copies, so the
-- shared contract is driven table-wise over all of them and only the real
-- divergence -- GitHub's private-repository handling -- gets its own block.
--
-- Everything below the manager is stubbed in `package.loaded` before the
-- manager is required: the fetcher (so no request is made), the README cache
-- (so no file is written), the repository cache (so a selection can be
-- scripted) and the preview manager (so no window is touched).

return function(H)
  local PROVIDERS = {
    { name = "github", manager = "reposcope.providers.github.readme.readme_manager" },
    { name = "gitlab", manager = "reposcope.providers.gitlab.readme.readme_manager" },
    { name = "codeberg", manager = "reposcope.providers.codeberg.readme.readme_manager" },
  }

  ---Builds the whole stub environment one manager runs in.
  ---@param provider string
  ---@return table env
  local function build_env(provider)
    local env = {
      fetched = {}, -- every fetch_raw/fetch_api call, in order
      cached = {}, -- every set_ram/set_file/set_updated_at call
      preview = {}, -- every preview-manager call
      notes = {},
      selected = nil, ---@type table|nil
      fresh = false,
      has_source = nil, ---@type string|nil
      metrics = {},
      answer_raw = nil, ---@type table|nil { success, content, err }
      answer_api = nil, ---@type table|nil
    }

    -- `hold` defers a route's callback instead of answering inline, so a spec
    -- can change the selection between "the request left" and "the answer
    -- arrived" -- the race `_show_unavailable` exists to lose.
    env.hold = {}
    env.pending = {}

    local function fetcher(kind)
      return function(owner, repo, branch, cb)
        env.fetched[#env.fetched + 1] = { kind = kind, owner = owner, repo = repo, branch = branch }
        if env.hold[kind] then
          env.pending[kind] = cb
          return
        end
        local answer = (kind == "raw") and env.answer_raw or env.answer_api
        if answer then cb(answer[1], answer[2], answer[3]) end
      end
    end

    env.stubs = {
      ["reposcope.providers." .. provider .. ".readme.readme_fetcher"] = {
        fetch_raw = fetcher("raw"),
        fetch_api = fetcher("api"),
      },
      ["reposcope.cache.readme_cache"] = {
        set_ram = function(o, r, c) env.cached[#env.cached + 1] = { kind = "ram", owner = o, repo = r, content = c } end,
        set_file = function(o, r, c) env.cached[#env.cached + 1] = { kind = "file", owner = o, repo = r, content = c } end,
        set_updated_at = function(o, r, u)
          env.cached[#env.cached + 1] = { kind = "updated_at", owner = o, repo = r, updated_at = u }
        end,
        has = function() return env.has_source ~= nil, env.has_source end,
        has_fresh = function() return env.fresh, env.fresh and (env.has_source or "ram") or nil end,
        get = function() return nil end,
        file_path = function(o, r) return o .. "__" .. r .. ".md" end,
      },
      ["reposcope.cache.repository_cache"] = {
        get_selected = function() return env.selected end,
      },
      ["reposcope.ui.preview.preview_manager"] = {
        update_preview = function(o, r) env.preview[#env.preview + 1] = { kind = "update", owner = o, repo = r } end,
        inject_content = function(buf, lines, ft)
          env.preview[#env.preview + 1] = { kind = "inject", buf = buf, lines = lines, ft = ft }
        end,
        clear_preview = function() env.preview[#env.preview + 1] = { kind = "clear" } end,
      },
      ["reposcope.utils.metrics"] = {
        record_metrics = function() return true end,
        increase_cache_hit = function(_, repo, source)
          env.metrics[#env.metrics + 1] = { kind = "ram", repo = repo, source = source }
        end,
        increase_fcache_hit = function(_, repo, source)
          env.metrics[#env.metrics + 1] = { kind = "file", repo = repo, source = source }
        end,
      },
      ["reposcope.utils.debug"] = {
        notify = function(msg) env.notes[#env.notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }

    return env
  end

  local function repo_of(overrides)
    return vim.tbl_extend("force", {
      name = "telescope.nvim",
      owner = { login = "nvim-telescope" },
      default_branch = "master",
      updated_at = "2026-01-01T00:00:00Z",
      html_url = "https://github.com/nvim-telescope/telescope.nvim",
    }, overrides or {})
  end

  ---Runs `fn(manager, env, request_state)` with the environment installed.
  local function with_manager(provider, module, fn)
    local env = build_env(provider)
    H.with_stubs(env.stubs, { module }, function()
      local request_state = require("reposcope.state.requests_state")
      request_state.clear_all_requests()
      fn(require(module), env, request_state)
      request_state.clear_all_requests()
    end)
  end

  for _, p in ipairs(PROVIDERS) do
    -------------------------------------------------------------------------
    -- Request-state gating: the manager is the only door to a README fetch
    -------------------------------------------------------------------------
    with_manager(p.name, p.manager, function(manager, env, request_state)
      env.selected = repo_of()

      manager.fetch_for_selected("never-registered")
      H.eq(#env.fetched, 0, p.name .. ": an unregistered UUID fetches nothing")

      request_state.register_request("u1")
      request_state.start_request("u1")
      manager.fetch_for_selected("u1")
      H.eq(#env.fetched, 0, p.name .. ": an already-active UUID is skipped, so navigation cannot double-fetch")
    end)

    -------------------------------------------------------------------------
    -- Nothing selected: the preview is cleared and the request closed
    -------------------------------------------------------------------------
    for _, selection in ipairs({
      { label = "no selection at all", value = nil },
      { label = "a selection with no name", value = { owner = { login = "o" } } },
      { label = "a selection with no owner", value = { name = "r" } },
      { label = "a selection with an empty owner table", value = { name = "r", owner = {} } },
    }) do
      with_manager(p.name, p.manager, function(manager, env, request_state)
        env.selected = selection.value
        request_state.register_request("u2")
        manager.fetch_for_selected("u2")
        H.drain()

        H.eq(#env.fetched, 0, ("%s: %s fetches nothing"):format(p.name, selection.label))
        H.falsy(request_state.is_registered("u2"), "and the request is closed rather than left hanging")
        H.eq(env.preview[1].kind, "clear", "the preview is cleared")
      end)
    end

    -------------------------------------------------------------------------
    -- A fresh cache entry short-circuits the network entirely
    -------------------------------------------------------------------------
    with_manager(p.name, p.manager, function(manager, env, request_state)
      env.selected = repo_of()
      env.fresh = true
      env.has_source = "ram"
      request_state.register_request("u3")

      manager.fetch_for_selected("u3")
      H.drain()

      H.eq(#env.fetched, 0, p.name .. ": a fresh cache entry makes no request")
      H.eq(env.preview[1].kind, "update", "the preview is refreshed from the cache")
      H.eq(env.preview[1].repo, "telescope.nvim", "for the selected repository")
      H.falsy(request_state.is_registered("u3"), "and the request is closed")
      H.eq(env.metrics[1].kind, "ram", "a RAM hit is recorded as a cache hit")
    end)

    with_manager(p.name, p.manager, function(manager, env, request_state)
      env.selected = repo_of()
      env.fresh = true
      env.has_source = "file"
      request_state.register_request("u4")
      manager.fetch_for_selected("u4")
      H.drain()
      H.eq(env.metrics[1].kind, "file", p.name .. ": a disk hit is recorded as a filecache hit, not a RAM one")
    end)

    -------------------------------------------------------------------------
    -- The raw route succeeds: RAM, disk and freshness are all written
    -------------------------------------------------------------------------
    with_manager(p.name, p.manager, function(manager, env, request_state)
      env.selected = repo_of()
      env.answer_raw = { true, "# README" }
      request_state.register_request("u5")

      manager.fetch_for_selected("u5")
      H.drain()

      H.eq(#env.fetched, 1, p.name .. ": one request")
      H.eq(env.fetched[1].kind, "raw", "and it goes to the raw host first")
      H.eq(env.fetched[1].branch, "master", "on the repository's default branch")

      local kinds = {}
      for _, c in ipairs(env.cached) do
        kinds[c.kind] = c
      end
      H.ok(kinds.ram, "the content is cached in RAM")
      H.eq(kinds.ram.content, "# README", "verbatim")
      H.ok(kinds.file, "and on disk")
      H.eq(kinds.updated_at.updated_at, "2026-01-01T00:00:00Z", "together with the repository's updated_at")
      H.eq(env.preview[#env.preview].kind, "update", "the preview is refreshed")
      H.falsy(request_state.is_registered("u5"), "and the request is closed")
    end)

    -- A repository with no default_branch falls back to `main`.
    with_manager(p.name, p.manager, function(manager, env, request_state)
      env.selected = { name = "telescope.nvim", owner = { login = "nvim-telescope" }, updated_at = "2026-01-01" }
      env.answer_raw = { true, "x" }
      request_state.register_request("u6")
      manager.fetch_for_selected("u6")
      H.drain()
      H.eq(env.fetched[1].branch, "main", p.name .. ": a repository without a default branch is fetched from main")
    end)

    -------------------------------------------------------------------------
    -- Raw fails -> the API gets its turn
    -------------------------------------------------------------------------
    with_manager(p.name, p.manager, function(manager, env, request_state)
      env.selected = repo_of()
      env.answer_raw = { false, nil, "404" }
      env.answer_api = { true, "# From the API" }
      request_state.register_request("u7")

      manager.fetch_for_selected("u7")
      H.drain()

      H.eq(#env.fetched, 2, p.name .. ": a failed raw fetch is followed by the API")
      H.eq(env.fetched[2].kind, "api", "which is the fallback route")
      H.eq(env.cached[1].content, "# From the API", "and its content is what gets cached")
      H.falsy(request_state.is_registered("u7"), "the request closes after the fallback")
      H.contains(table.concat(env.notes, "\n"), "Raw README fetch failed", "the raw failure is reported at dev level")
    end)

    -------------------------------------------------------------------------
    -- Both routes fail: the preview says so, but only for the right entry
    -------------------------------------------------------------------------
    with_manager(p.name, p.manager, function(manager, env, request_state)
      local ui_state = require("reposcope.state.ui.ui_state")
      local saved_buf = ui_state.buffers.preview
      ui_state.buffers.preview = 4242

      env.selected = repo_of()
      env.answer_raw = { false, nil, "404" }
      env.answer_api = { false, nil, "404" }
      request_state.register_request("u8")

      manager.fetch_for_selected("u8")
      H.drain()

      H.eq(#env.cached, 0, p.name .. ": a failure caches nothing -- a 404 must not poison the cache")
      H.falsy(request_state.is_registered("u8"), "the request still closes")

      local injected
      for _, call in ipairs(env.preview) do
        if call.kind == "inject" then injected = call end
      end
      H.ok(injected, "the preview is told there is no README")
      H.eq(injected.buf, 4242, "in the preview buffer")
      H.contains(injected.lines[1], "couldn't be fetched", "with a plain sentence, not an error")
      H.eq(injected.ft, "text", "as text, not markdown -- there is no markdown to render")

      ui_state.buffers.preview = saved_buf
    end)

    -- The user moved on while the fetch was in flight: the message must not
    -- paint over the README of whatever they moved to.
    with_manager(p.name, p.manager, function(manager, env, request_state)
      local ui_state = require("reposcope.state.ui.ui_state")
      local saved_buf = ui_state.buffers.preview
      ui_state.buffers.preview = 4242

      env.selected = repo_of()
      env.answer_raw = { false, nil, "404" }
      env.hold.api = true -- the API answer is delivered by hand, below
      request_state.register_request("u9")

      manager.fetch_for_selected("u9")
      H.ok(env.pending.api, "the API fallback is in flight")

      -- The user navigates away before the answer arrives.
      env.selected = repo_of({ name = "fzf-lua", owner = { login = "ibhagwan" } })
      env.pending.api(false, nil, "404")
      H.drain()

      for _, call in ipairs(env.preview) do
        H.ok(call.kind ~= "inject", p.name .. ": a late failure does not overwrite the new selection's preview")
      end

      ui_state.buffers.preview = saved_buf
    end)

    -------------------------------------------------------------------------
    -- prefetch: cheap, silent, and it never touches the selection
    -------------------------------------------------------------------------
    with_manager(p.name, p.manager, function(manager, env)
      manager.prefetch(nil)
      manager.prefetch({})
      manager.prefetch({ name = "r" })
      manager.prefetch({ owner = { login = "o" } })
      H.eq(#env.fetched, 0, p.name .. ": prefetch refuses an incomplete repository")

      env.fresh = true
      manager.prefetch(repo_of())
      H.eq(#env.fetched, 0, "and skips anything already fresh")

      env.fresh = false
      env.answer_raw = { true, "# prefetched" }
      manager.prefetch(repo_of())
      H.drain()
      H.eq(#env.fetched, 1, "otherwise it makes exactly one request")
      H.eq(env.fetched[1].kind, "raw", "to the cheap route")
      H.eq(#env.cached, 3, "and caches RAM + disk + freshness")
      H.eq(#env.preview, 0, "without touching the preview at all")
    end)

    with_manager(p.name, p.manager, function(manager, env)
      env.answer_raw = { false, nil, "404" }
      manager.prefetch(repo_of())
      H.drain()
      H.eq(#env.fetched, 1, p.name .. ": a failed prefetch does not retry against the API")
      H.eq(#env.cached, 0, "and caches nothing")
      H.eq(#env.notes, 0, "silently -- prefetch is a background optimization")
    end)
  end

  ---------------------------------------------------------------------------
  -- GitHub only: a private repository skips the raw host entirely
  ---------------------------------------------------------------------------
  do
    local module = "reposcope.providers.github.readme.readme_manager"

    with_manager("github", module, function(manager, env, request_state)
      env.selected = repo_of({ private = true })
      env.answer_api = { true, "# private readme" }
      request_state.register_request("p1")

      manager.fetch_for_selected("p1")
      H.drain()

      H.eq(#env.fetched, 1, "a private repository makes one request, not two")
      H.eq(env.fetched[1].kind, "api", "and it goes straight to the API")
      H.eq(env.cached[1].content, "# private readme", "whose content is cached")
    end)

    with_manager("github", module, function(manager, env)
      env.answer_api = { true, "# private readme" }
      manager.prefetch(repo_of({ private = true }))
      H.drain()
      H.eq(
        env.fetched[1].kind,
        "api",
        "prefetch takes the same shortcut -- before it, private repos were never pre-cached"
      )
    end)

    -- `private` is a tri-state in practice (absent for most search results);
    -- only an explicit `true` diverts.
    with_manager("github", module, function(manager, env, request_state)
      env.selected = repo_of({ private = false })
      env.answer_raw = { true, "# public" }
      request_state.register_request("p2")
      manager.fetch_for_selected("p2")
      H.drain()
      H.eq(env.fetched[1].kind, "raw", "an explicitly public repository takes the raw route")
    end)
  end
end
