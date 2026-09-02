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
  H.eq(#captured.contribution.sources, 1, "exactly one")

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
