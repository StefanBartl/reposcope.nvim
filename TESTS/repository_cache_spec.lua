-- TESTS/repository_cache_spec.lua — the in-memory result cache: what a decoded
-- API response turns into, and what the list buffer gets to show.

return function(H)
  local cache = require("reposcope.cache.repository_cache")

  local function response(items) return { total_count = #items, items = items } end

  -- Empty --------------------------------------------------------------------
  cache.clear()
  H.eq(cache.get().total_count, 0, "a cleared cache counts nothing")
  H.eq(#cache.get_list(), 1, "and the display list is one entry")
  H.eq(cache.get_list()[1], "", "which is empty -- the list buffer needs a line to render")

  -- Filling ------------------------------------------------------------------
  cache.set(response({
    { name = "telescope.nvim", owner = { login = "nvim-telescope" }, description = "Find files" },
    { name = "fzf-lua", owner = { login = "ibhagwan" }, description = "Fuzzy" },
  }))

  H.eq(cache.get().total_count, 2, "total_count comes through")
  H.eq(#cache.get_list(), 2, "one display line per repository")
  H.contains(cache.get_list()[1], "telescope.nvim", "the line names the repository")

  -- Lookup -------------------------------------------------------------------
  local found = cache.get_by_name("fzf-lua")
  H.ok(found, "a repository can be looked up by name")
  H.eq(found.name, "fzf-lua", "and it is the right one")

  -- A miss is a nil, not a crash. `get_by_name` is reached from user input --
  -- the name under the cursor -- and the list can be stale by the time it runs.
  H.eq(cache.get_by_name("does-not-exist"), nil, "a miss returns nil")

  -- Fields the API may omit ---------------------------------------------------
  -- Search results are not uniform: description is null for plenty of
  -- repositories, and a decoded null is `vim.NIL`, not `nil`. If that reached
  -- the list line it would render as "userdata: 0x...".
  cache.set(response({ { name = "bare", owner = { login = "someone" } } }))
  local line = cache.get_list()[1]
  H.ok(type(line) == "string", "a repository without a description still builds a line")
  H.excludes(line, "userdata", "and nothing leaks a raw userdata into it")

  -- total_count without items -------------------------------------------------
  cache.set({ total_count = 99 })
  H.eq(cache.get().total_count, 99, "a response with no items keeps its count")
  H.eq(#cache.get_list(), 1, "and falls back to the single empty line")

  cache.clear()
end
