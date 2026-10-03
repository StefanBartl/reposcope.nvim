-- TESTS/hover_spec.lua — the hover.nvim contribution.
--
-- The hazard this integration carries is specific and worth stating: a
-- repository slug is spelled exactly like prose. `owner/repo` is two
-- components, no extension, no root — the same shape as `and/or`,
-- `input/output` or `read/write`, which hover.nvim's bare-path rules
-- deliberately refuse to treat as targets for precisely that reason.
--
-- So the slug test is only half the guarantee. The other half is that the
-- source answers **only for repositories reposcope has actually cached**, and
-- these specs pin both halves separately: a wrong slug test would make it
-- noisy, and a missing cache check would make it noisy in a way no slug test
-- could fix.
--
-- hover.nvim is stubbed rather than required: this suite runs with `-u NONE`
-- and only reposcope plus lib.nvim on the runtimepath.

---@param H table harness
return function(H)
  local hover = require("reposcope.hover")

  -- ------------------------------------------------------------ slug shape --
  local function slug(line, col)
    local owner, repo = hover.slug_at(line, col)
    if not owner then return nil end
    return owner .. "/" .. repo
  end

  H.eq(slug("see StefanBartl/hover.nvim here", 12), "StefanBartl/hover.nvim", "a plain slug")
  H.eq(slug("(StefanBartl/hover.nvim)", 5), "StefanBartl/hover.nvim", "parenthesised")
  H.eq(slug('"owner/repo"', 3), "owner/repo", "quoted")
  H.eq(slug("dep: my-org/my.repo_1", 8), "my-org/my.repo_1", "dots, dashes and underscores")

  H.eq(slug("owner/repo/tree/main", 3), nil, "three components is a path into a repository")
  H.eq(slug("just-a-word here", 3), nil, "one component is a word")
  H.eq(slug("", 0), nil, "an empty line")
  H.eq(slug("see it", 99), nil, "a column past the end")
  H.eq(slug("a  /  b", 0), nil, "spaces are not part of a slug")

  -- ------------------------------------------------------- cache gating -----
  local real_registry = package.loaded["hover.registry"]
  local real_cache = package.loaded["reposcope.cache.readme_cache"]
  local captured = {}

  package.loaded["hover.registry"] = {
    register = function(name, contribution)
      captured.name = name
      captured.contribution = contribution
    end,
  }

  hover._reset()
  H.ok(hover.setup(), "setup registers when hover.nvim is there")
  H.eq(captured.name, "reposcope.nvim", "under this plugin's name")
  H.ok(type(captured.contribution.sources) == "table", "as a source, not a position")
  H.eq(#captured.contribution.sources, 2, "the cache source, then the on-request fetch source")
  H.eq(captured.contribution.sources[2].on_request, true, "the fetch source is only asked on an explicit request")

  local answer = captured.contribution.sources[1]

  -- A README on disk, so the "cached" branch is a real file rather than a
  -- mocked stat: what the source hands back is a path hover.nvim will open.
  local tmp = vim.fn.tempname() .. ".md"
  vim.fn.writefile({ "# real" }, tmp)

  package.loaded["reposcope.cache.readme_cache"] = {
    has = function(owner, repo) return owner == "known" and repo == "repo" end,
    file_path = function() return tmp end,
  }

  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    "see known/repo here",
    "see unknown/repo here",
    "see and/or here",
  })

  H.eq(answer(buf, 1, 5), tmp, "a cached slug resolves to its README on disk")
  H.eq(answer(buf, 2, 5), nil, "an uncached slug is declined")
  H.eq(answer(buf, 3, 5), nil, "prose that is shaped like a slug is declined")
  H.eq(answer(-1, 1, 5), nil, "an invalid buffer is declined")

  -- The cache says yes but the file is gone: a dangling entry must not be
  -- handed to hover.nvim as a path, which would preview "no such file".
  package.loaded["reposcope.cache.readme_cache"] = {
    has = function() return true end,
    file_path = function() return tmp .. ".missing" end,
  }
  H.eq(answer(buf, 1, 5), nil, "a cache entry whose file is gone is declined")

  vim.fn.delete(tmp)
  vim.api.nvim_buf_delete(buf, { force = true })

  -- --------------------------------------------- on-request fetch source ---
  -- An uncached slug is fetched only for an explicit request, once, remembered
  -- (for a while) when it fails, and shown (hover re-asked) when it arrives.
  do
    local fetch_source = captured.contribution.sources[2].fn
    local real_notify = vim.notify
    local env = { provider = "github", fetched = {}, done = nil, shown = 0, show_opts = nil, notes = {} }

    -- "Cached" means "on disk" to the callback, which checks the file.
    local cached_file = vim.fn.tempname() .. ".md"
    vim.fn.writefile({ "# cached" }, cached_file)
    env.ram = nil -- text the RAM cache holds, when the file is missing
    env.written = {}

    local fbuf = vim.api.nvim_create_buf(false, true)

    local ok, err = pcall(H.with_stubs, {
      ["reposcope.config"] = { get_option = function() return env.provider end },
      ["reposcope.controllers.provider_controller"] = {
        prefetch_readme = function(repo, on_done)
          env.fetched[#env.fetched + 1] = repo
          env.done = on_done
        end,
      },
      ["reposcope.cache.readme_cache"] = {
        has = function() return false end,
        file_path = function() return env.file or cached_file end,
        get_ram = function() return env.ram end,
        set_file = function(o, r, text)
          env.written[#env.written + 1] = { o, r, text }
          return true
        end,
      },
      ["hover"] = {
        show = function(o)
          env.shown, env.show_opts = env.shown + 1, o
        end,
      },
    }, {}, function()
      vim.notify = function(msg) env.notes[#env.notes + 1] = msg end

      vim.api.nvim_buf_set_lines(
        fbuf,
        0,
        -1,
        false,
        { "see new/thing here", "and/or", "../.. x", "see lua/plugins here" }
      )
      vim.api.nvim_set_current_buf(fbuf)
      vim.api.nvim_win_set_cursor(0, { 1, 6 })

      hover._reset()
      H.eq(fetch_source(fbuf, 1, 6), nil, "the fetch source never answers synchronously")
      H.eq(#env.fetched, 1, "an uncached slug starts a fetch")
      H.eq(env.fetched[1].owner.login, "new", "for that owner")
      H.eq(env.fetched[1].name, "thing", "and repository")
      H.eq(env.fetched[1].default_branch, "HEAD", "on the default branch, which is unknown here")
      H.eq(env.fetched[1].prefer_api, true, "through the API, which finds whatever the README is called")

      fetch_source(fbuf, 1, 6)
      H.eq(#env.fetched, 1, "a second ask while it is in flight does not start another")

      env.done(true)
      H.eq(env.shown, 1, "when it arrives under the cursor, hover is asked again")
      H.eq(env.show_opts and env.show_opts.force, true, "with force, so the re-ask is not declined by the volume gates")

      -- A different place in the meantime: no float for text the reader left.
      hover._reset()
      env.fetched, env.shown = {}, 0
      fetch_source(fbuf, 1, 6)
      vim.api.nvim_win_set_cursor(0, { 2, 1 })
      env.done(true)
      H.eq(env.shown, 0, "if the cursor moved on, no float opens")
      H.contains(env.notes[#env.notes], "ask again", "the reader is told it is cached")

      -- A README that is only in RAM must not send hover round in circles: the
      -- cache source needs the file, so the callback writes it out first ...
      hover._reset()
      vim.api.nvim_win_set_cursor(0, { 1, 6 })
      env.fetched, env.shown, env.written = {}, 0, {}
      env.file = cached_file .. ".missing"
      env.ram = "# only in RAM"
      fetch_source(fbuf, 1, 6)
      env.done(true)
      H.eq(#env.written, 1, "a RAM-only README is written to disk before hover is asked again")
      H.eq(env.written[1][3], "# only in RAM", "with the text the RAM cache held")
      H.eq(env.shown, 1, "and then shown, once")

      -- ... and counts as a failure when there is nothing to write (no loop).
      hover._reset()
      env.fetched, env.shown, env.written = {}, 0, {}
      env.ram = nil
      fetch_source(fbuf, 1, 6)
      env.done(true)
      H.eq(env.shown, 0, "'cached' without any file or RAM copy never re-asks hover")
      H.contains(env.notes[#env.notes], "could not fetch", "and the reader is told")
      env.file, env.ram = nil, nil

      -- A failed fetch is remembered for a while, not retried on every request,
      -- and a repeat ask says why nothing happens.
      hover._reset()
      env.fetched = {}
      fetch_source(fbuf, 1, 6)
      env.done(false)
      H.contains(env.notes[#env.notes], "could not fetch", "a failure is reported")
      fetch_source(fbuf, 1, 6)
      H.eq(#env.fetched, 1, "a slug that failed is not fetched again right away")
      H.contains(env.notes[#env.notes], "no README found", "and a repeat ask is answered, not silent")

      -- ... but not forever: offline or rate-limited is transient.
      local real_now = vim.uv.now
      vim.uv.now = function() return real_now() + 6 * 60 * 1000 end
      local ok_later, err_later = pcall(fetch_source, fbuf, 1, 6)
      vim.uv.now = real_now
      H.ok(ok_later, tostring(err_later))
      H.eq(#env.fetched, 2, "after the cool-down the slug is fetched again")

      -- Declined without any request: `..` is never a namespace, an existing
      -- path is that path, and other providers have no known branch.
      hover._reset()
      env.fetched = {}
      fetch_source(fbuf, 3, 1)
      H.eq(#env.fetched, 0, "dot-only components are never fetched")

      local base = vim.fn.tempname()
      vim.fn.mkdir(base .. "/lua/plugins", "p")
      local real_cwd = vim.uv.cwd()
      vim.uv.chdir(base)
      local ok_path, err_path = pcall(fetch_source, fbuf, 4, 6)
      vim.uv.chdir(real_cwd)
      vim.fn.delete(base, "rf")
      H.ok(ok_path, tostring(err_path))
      H.eq(#env.fetched, 0, "text that is an existing relative path is not fetched")

      env.provider = "gitlab"
      fetch_source(fbuf, 1, 6)
      H.eq(#env.fetched, 0, "another provider than GitHub is declined")
    end)

    vim.notify = real_notify
    vim.fn.delete(cached_file)
    if vim.api.nvim_buf_is_valid(fbuf) then vim.api.nvim_buf_delete(fbuf, { force = true }) end
    if not ok then error(err, 0) end
  end

  -- ------------------------------------------------------- degradation ------
  package.loaded["hover.registry"] = nil
  local real_preload = package.preload["hover.registry"]
  package.preload["hover.registry"] = function() error("module 'hover.registry' not found") end
  hover._reset()
  H.falsy(hover.setup(), "without hover.nvim, setup declines quietly")
  package.preload["hover.registry"] = real_preload

  -- -------------------------------------------------------- idempotence -----
  package.loaded["hover.registry"] = {
    register = function(name) captured.name = name end,
  }
  hover._reset()
  H.ok(hover.setup(), "first setup registers")
  captured.name = nil
  H.ok(hover.setup(), "second reports success")
  H.eq(captured.name, nil, "but does not register again")

  hover._reset()
  package.loaded["hover.registry"] = real_registry
  package.loaded["reposcope.cache.readme_cache"] = real_cache
end
