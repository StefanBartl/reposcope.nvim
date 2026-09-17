-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/session_state_spec.lua — `:Reposcope session save|restore|clear`.
--
-- The session is the last search *context*: provider, visible prompt fields
-- and their text, the built query, and the filter/sort applied afterwards.
-- Restoring it re-runs the search, so the modules that would talk to a
-- provider are stubbed in `package.loaded` before the module is required.

return function(H)
  local dir, cleanup = H.fixture("session_state")
  local path = dir .. "/session.json"

  local config = require("reposcope.config")
  local saved_path_fn = config.get_session_path
  config.get_session_path = function() return path end

  ---@param env table  scripted answers and recorders
  ---@param fn fun(session: table, env: table): nil
  local function with_session(env, fn)
    env.searched = {}
    env.filtered = {}
    env.sorted = {}

    H.with_stubs({
      ["reposcope.controllers.provider_controller"] = {
        get_active_provider = function() return env.provider or "github" end,
        fetch_repositories_and_display = function(query, on_success)
          env.searched[#env.searched + 1] = query
          if on_success then on_success() end
        end,
      },
      ["reposcope.ui.prompt.prompt_input"] = {
        get_last_query = function() return env.query or "" end,
        collect = function() return {} end,
      },
      ["reposcope.ui.actions.filter_repos"] = {
        get_current_filter = function() return env.filter or "" end,
        apply_filter = function(text) env.filtered[#env.filtered + 1] = text end,
      },
      ["reposcope.ui.actions.sort_prompt"] = {
        get_current_sort = function() return env.sort or "relevance" end,
        apply_sort = function(mode) env.sorted[#env.sorted + 1] = mode end,
      },
    }, { "reposcope.state.session_state" }, function() fn(require("reposcope.state.session_state"), env) end)
  end

  local ok, err = pcall(function()
    local prompt_config = require("reposcope.ui.prompt.prompt_config")
    local prompt_state = require("reposcope.state.ui.prompt_state")
    local saved_fields = vim.deepcopy(prompt_config.get_fields())
    local saved_input = vim.deepcopy(prompt_state.input)
    local saved_provider = config.options.provider

    -------------------------------------------------------------------------
    -- Nothing saved yet
    -------------------------------------------------------------------------
    vim.fn.delete(path)
    with_session({}, function(session)
      H.falsy(session.restore(), "restoring without a saved session reports failure")
      H.falsy(session.clear(), "and clearing one reports there was nothing to clear")
    end)

    -------------------------------------------------------------------------
    -- Saving captures the whole search context
    -------------------------------------------------------------------------
    prompt_config.set_fields({ "prefix", "keywords", "owner" })
    prompt_state.set_field_text("keywords", "telescope")
    prompt_state.set_field_text("owner", "nvim-telescope")

    with_session({
      provider = "gitlab",
      query = "telescope nvim-telescope",
      filter = "lua",
      sort = "stars",
    }, function(session)
      H.ok(session.save(), "saving reports success")
      H.ok(vim.fn.filereadable(path) == 1, "and writes the session file")

      local decoded = vim.json.decode(H.read(path))
      H.eq(decoded.provider, "gitlab", "the active provider is recorded")
      H.eq(decoded.query, "telescope nvim-telescope", "the last built query is recorded")
      H.eq(decoded.filter_text, "lua", "as is the active filter")
      H.eq(decoded.sort_mode, "stars", "and the active sort mode")
      H.eq(decoded.input.keywords, "telescope", "every prompt field's text is recorded")
      H.eq(decoded.input.owner, "nvim-telescope", "including the second one")
      H.eq(decoded.fields[1], "prefix", "and the visible field layout")

      -- Saving twice overwrites rather than appending: this is one evolving
      -- file, not a keyed cache.
      H.ok(session.save(), "a second save also succeeds")
      H.eq(#vim.json.decode(H.read(path)).fields, 3, "and the file still holds exactly one session")
    end)

    -------------------------------------------------------------------------
    -- Restoring re-applies everything, in the right order
    -------------------------------------------------------------------------
    config.options.provider = "github"
    prompt_config.set_fields({ "keywords" })
    prompt_state.input = {}

    with_session({}, function(session, env)
      H.ok(session.restore(), "restoring an existing session reports success")
      H.eq(config.options.provider, "gitlab", "the saved provider becomes the active one again")
      H.eq(#prompt_config.get_fields(), 3, "the saved prompt layout is restored")
      H.eq(prompt_state.get_field_text("keywords"), "telescope", "as is each field's text")
      H.eq(prompt_state.get_field_text("owner"), "nvim-telescope", "for every field")

      H.eq(#env.searched, 1, "the saved query is re-run")
      H.eq(env.searched[1], "telescope nvim-telescope", "verbatim")
      -- Filter and sort are re-applied from the search's completion callback,
      -- because there is nothing to filter or sort until results arrive.
      H.eq(env.filtered[1], "lua", "the filter is re-applied once the search completes")
      H.eq(env.sorted[1], "stars", "and so is the sort mode")
    end)

    -------------------------------------------------------------------------
    -- A session with nothing to re-run still restores the prompt
    -------------------------------------------------------------------------
    with_session({ query = "", filter = "", sort = "relevance" }, function(session, env)
      H.ok(session.save(), "a session with no query can be saved")
      H.ok(session.restore(), "and restored")
      H.eq(#env.searched, 0, "without re-running an empty search")
    end)

    -- `relevance` is the default sort, so restoring it is a no-op rather than
    -- a redundant re-sort of an already relevance-ordered list.
    with_session({ query = "x", filter = "", sort = "relevance" }, function(session, env)
      session.save()
      session.restore()
      H.eq(#env.searched, 1, "the query is re-run")
      H.eq(#env.sorted, 0, "but the default sort is not re-applied")
      H.eq(#env.filtered, 0, "and neither is an empty filter")
    end)

    -------------------------------------------------------------------------
    -- A corrupt or partial session file
    -------------------------------------------------------------------------
    vim.fn.writefile({ "{not json" }, path)
    with_session(
      {},
      function(session) H.falsy(session.restore(), "a corrupt session file is refused, not acted on") end
    )

    -- Every field is optional and individually type-checked, so a file
    -- written by an older version cannot crash the restore.
    vim.fn.writefile({ vim.json.encode({ provider = 42, fields = "nope", input = "nope", query = 7 }) }, path)
    with_session({}, function(session, env)
      config.options.provider = "github"
      H.ok(session.restore(), "a session with wrongly-typed fields still restores")
      H.eq(config.options.provider, "github", "ignoring the values it cannot use")
      H.eq(#env.searched, 0, "and running no search")
    end)

    -------------------------------------------------------------------------
    -- Clearing
    -------------------------------------------------------------------------
    with_session({ query = "x" }, function(session)
      session.save()
      H.ok(session.clear(), "clearing an existing session reports success")
      H.eq(vim.fn.filereadable(path), 0, "and removes the file")
      H.falsy(session.restore(), "so there is nothing left to restore")
    end)

    prompt_config.set_fields(saved_fields)
    prompt_state.input = saved_input
    config.options.provider = saved_provider
  end)

  config.get_session_path = saved_path_fn
  package.loaded["reposcope.state.session_state"] = nil
  cleanup()
  if not ok then error(err, 0) end
end
