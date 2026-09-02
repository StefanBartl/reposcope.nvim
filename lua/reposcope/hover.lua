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
---     anything slug-shaped. An unknown `foo/bar` is declined here and falls
---     through to whatever hover.nvim would have done anyway.
---   * **It runs before the bare-path source**, which registration order
---     already guarantees, so a slug that is *also* a real directory is read
---     as the repository. That is the more specific reading of the same text.
---
---@see reposcope.cache.readme_cache

local M = {}

local api = vim.api

---@type boolean
local _registered = false

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
function M._reset() _registered = false end

return M
