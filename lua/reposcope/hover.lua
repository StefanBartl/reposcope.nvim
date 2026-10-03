---@module 'reposcope.hover'
---@brief Preview a cached README when the cursor rests on `owner/repo`.
---@description
--- A repository slug turns up constantly outside reposcope's own UI: in a
--- plugin spec, a lockfile, a dependency list, a note, a README's own "see
--- also". Reposcope has already fetched and cached the README of every
--- repository it has shown, so the answer to "what is that" is on disk and
--- costs a file read.
---
--- This registers a **source** with
--- [hover.nvim](https://github.com/StefanBartl/hover.nvim): it says what the
--- cursor is on, and hands back the *path* of the cached README rather than
--- the slug. hover.nvim then classifies a `.md` file and runs its own markdown
--- preview -- the same one it uses for any other markdown target.
---
--- **That indirection is the whole design, and it was chosen over the
--- alternative.** hover.nvim could have grown a `repository` target type with
--- a preview to match; riding the existing markdown path needs no change on
--- its side at all, and gets the heading rendering, the scrolling and the
--- file-head logic for free.
---
--- **A slug is not a path, and that is the hazard.** `owner/repo` is two
--- components, no extension, no root -- spelled exactly like `and/or` or
--- `input/output`, which hover.nvim's bare-path rules deliberately treat as
--- prose. Two things keep this from becoming the noise those rules exist to
--- prevent:
---
---   * **It answers only for slugs reposcope has actually cached.** Not for
---     anything slug-shaped. An unknown `foo/bar` is declined by the cache
---     source and falls through to whatever hover.nvim would have done anyway
---     -- unless the reader explicitly asks (`:Hover show`), which also
---     starts a fetch (see `fetch_for_request`).
---   * **It runs before the bare-path source**, which registration order
---     already guarantees, so a slug that is *also* a real directory is read
---     as the repository. That is the more specific reading of the same text.
---
---@see reposcope.cache.readme_cache

local M = {}

local api = vim.api

---@type boolean
local _registered = false

---Slugs being fetched right now, and the time (ms, `vim.uv.now()`) at which a
---fetch of a slug last failed. A failure covers a missing repository or README
---but also being offline or rate-limited, so it is remembered for
---`RETRY_AFTER_MS` rather than for the whole session.
---@type table<string, true>
local _pending = {}
---@type table<string, integer>
local _failed = {}
local RETRY_AFTER_MS = 5 * 60 * 1000

---@internal
--- The `owner/repo` the cursor is inside, or nil.
---
--- Bounded by the characters GitHub, GitLab and Codeberg actually allow in a
--- namespace or a project name, so `(owner/repo)` and `"owner/repo"` are the
--- same slug and `owner/repo/tree/main` is not one.
---@param line string
---@param col integer 0-based
---@return string|nil owner
---@return string|nil repo
local function slug_at(line, col)
  if type(line) ~= "string" or line == "" then return nil end
  local allowed = "[%w%._%-]"
  local char = line:sub(col + 1, col + 1)
  if not (char:match(allowed) or char == "/") then return nil end

  local first = col + 1
  while first > 1 do
    local prev = line:sub(first - 1, first - 1)
    if prev:match(allowed) or prev == "/" then
      first = first - 1
    else
      break
    end
  end
  local last = col + 1
  while last < #line do
    local nxt = line:sub(last + 1, last + 1)
    if nxt:match(allowed) or nxt == "/" then
      last = last + 1
    else
      break
    end
  end

  local run = line:sub(first, last)
  -- Exactly two components. Three is a path into a repository, one is a word.
  local owner, repo = run:match("^([%w%._%-]+)/([%w%._%-]+)$")
  if not owner or owner == "" or repo == "" then return nil end
  return owner, repo
end

---@internal
--- Fetch the README of an uncached slug and, when it arrives, ask hover.nvim
--- again -- if the cursor is still on that slug. Sources answer synchronously,
--- so this one answers nothing now and the second ask gets the file.
---
--- Only reached for an explicit request (`on_request`): fetching discloses the
--- text under the cursor to a host, and a trigger that fires while scrolling
--- would turn every `and/or` into a request.
---@param bufnr integer
---@param owner string
---@param repo string
---@return nil
local function fetch_for_request(bufnr, owner, repo)
  -- `..` and friends are slug-shaped but never a namespace or a project.
  if owner:match("^%.+$") or repo:match("^%.+$") then return end
  -- The cache layout is per provider, and only GitHub's README endpoint is
  -- known to take an unknown default branch ("HEAD") -- decline elsewhere.
  if require("reposcope.config").get_option("provider") ~= "github" then return end

  local key = owner .. "/" .. repo
  if _pending[key] then return end
  local failed_at = _failed[key]
  if failed_at and vim.uv.now() - failed_at < RETRY_AFTER_MS then
    vim.notify(
      ("[reposcope] no README found for %s (failed earlier, ask again in a few minutes)"):format(key),
      vim.log.levels.WARN
    )
    return
  end
  _pending[key] = true
  vim.notify(("[reposcope] fetching the README of %s ..."):format(key), vim.log.levels.INFO)

  require("reposcope.controllers.provider_controller").prefetch_readme({
    name = repo,
    description = "",
    html_url = "https://github.com/" .. key,
    owner = { login = owner },
    default_branch = "HEAD",
    prefer_api = true,
  }, function(ok)
    _pending[key] = nil

    -- "Cached" has to mean "on disk" here: the cache source hands hover.nvim
    -- a FILE. A README that is only in RAM (a favorite whose cache file was
    -- cleaned, a file deleted mid-session, an unwritable cache dir) would make
    -- the re-ask below decline, fetch again, be told "cached" again, and so on
    -- without end. Write the RAM copy out, or count it as a failure.
    if ok then
      local cache = require("reposcope.cache.readme_cache")
      if not vim.uv.fs_stat(cache.file_path(owner, repo)) then
        local text = cache.get_ram(owner, repo)
        ok = text ~= nil and cache.set_file(owner, repo, text) == true
      end
    end

    if not ok then
      _failed[key] = vim.uv.now()
      vim.notify(
        ("[reposcope] could not fetch a README for %s (no such repository, no README, offline or rate-limited)"):format(
          key
        ),
        vim.log.levels.WARN
      )
      return
    end

    -- Ask again only where the reader still is: a float for text they have
    -- since left would be a question nobody asked.
    local still_there = false
    if api.nvim_buf_is_valid(bufnr) and api.nvim_get_current_buf() == bufnr then
      local pos = api.nvim_win_get_cursor(0)
      local line = api.nvim_buf_get_lines(bufnr, pos[1] - 1, pos[1], false)[1]
      local o, r = slug_at(line, pos[2])
      still_there = o == owner and r == repo
    end
    if still_there then
      local shown, hover = pcall(require, "hover")
      if shown and type(hover.show) == "function" then
        pcall(hover.show, { force = true })
        return
      end
    end
    vim.notify(("[reposcope] README of %s cached -- ask again to see it"):format(key), vim.log.levels.INFO)
  end)
end

--- Register the source with hover.nvim, if it is installed.
---@return boolean registered
function M.setup()
  if _registered then return true end

  local ok, registry = pcall(require, "hover.registry")
  if not ok or type(registry) ~= "table" or type(registry.register) ~= "function" then return false end

  registry.register("reposcope.nvim", {
    sources = {
      ---@param bufnr integer
      ---@param row integer 1-based
      ---@param col integer 0-based
      ---@return string|nil
      function(bufnr, row, col)
        if not api.nvim_buf_is_valid(bufnr) then return nil end
        local line = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
        local owner, repo = slug_at(line, col)
        if not owner or not repo then return nil end

        -- Confirmed against the cache, not guessed. `has` answers for RAM and
        -- disk both; the path is asked for separately because hover.nvim
        -- wants a file to preview, not the text.
        local cache = require("reposcope.cache.readme_cache")
        if not cache.has(owner, repo) then return nil end
        local path = cache.file_path(owner, repo)
        if vim.uv.fs_stat(path) then return path end
        return nil
      end,

      -- Second, and only for an explicit request (`:Hover show`): a slug that
      -- is not cached is fetched, then shown. Declines now, answers on the
      -- re-ask the fetch triggers -- see `fetch_for_request`.
      {
        on_request = true,
        ---@param bufnr integer
        ---@param row integer 1-based
        ---@param col integer 0-based
        ---@return nil
        fn = function(bufnr, row, col)
          if not api.nvim_buf_is_valid(bufnr) then return nil end
          local line = api.nvim_buf_get_lines(bufnr, row - 1, row, false)[1]
          local owner, repo = slug_at(line, col)
          if not owner or not repo then return nil end

          -- A path that exists is that path, not a repository: hover.nvim
          -- reads `lua/plugins` as the directory, and a request to GitHub
          -- (plus two notices) for it would be noise at best, and at worst a
          -- late README that replaces the file the reader pointed at.
          local name = api.nvim_buf_get_name(bufnr)
          local bases = { vim.uv.cwd() }
          if name ~= "" then table.insert(bases, 1, vim.fs.dirname(name)) end
          for _, base in ipairs(bases) do
            if base and vim.uv.fs_stat(base .. "/" .. owner .. "/" .. repo) then return nil end
          end

          fetch_for_request(bufnr, owner, repo)
          return nil
        end,
      },
    },
  })

  _registered = true
  return true
end

---@internal
--- The slug test on its own, for the spec suite.
---@param line string
---@param col integer
---@return string|nil owner
---@return string|nil repo
function M.slug_at(line, col) return slug_at(line, col) end

---@internal
--- Forget the registration. Tests only.
---@return nil
function M._reset()
  _registered = false
  _pending = {}
  _failed = {}
end

return M
