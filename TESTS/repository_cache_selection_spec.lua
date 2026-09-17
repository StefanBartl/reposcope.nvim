-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/repository_cache_selection_spec.lua — the half of the repository
-- cache that `repository_cache_spec.lua` does not reach: resolving "which
-- repository is under the cursor" out of the list buffer, and the
-- relevance-ordering snapshot behind `:Reposcope sort relevance`.
--
-- Driven against a real scratch buffer holding real list lines, because the
-- resolution is a *text* parse of what is on screen -- stubbing the buffer
-- away would remove the thing being tested.

return function(H)
  local cache = require("reposcope.cache.repository_cache")
  local ui_state = require("reposcope.state.ui.ui_state")
  local list_window = require("reposcope.ui.list.list_window")

  local saved_buf = ui_state.buffers.list
  local saved_line = list_window.highlighted_line

  local buf = vim.api.nvim_create_buf(false, true)

  local ok, err = pcall(function()
    local items = {
      { name = "telescope.nvim", owner = { login = "nvim-telescope" }, description = "Find files" },
      { name = "fzf-lua", owner = { login = "ibhagwan" }, description = "Fuzzy: with a colon" },
    }

    local function show(lines)
      vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
      ui_state.buffers.list = buf
    end

    -------------------------------------------------------------------------
    -- Nothing to select
    -------------------------------------------------------------------------
    cache.clear()
    list_window.highlighted_line = 1
    show({ "" })
    H.eq(cache.get_selected(), nil, "an empty cache has no selection")

    cache.set({ total_count = #items, items = vim.deepcopy(items) })

    ui_state.buffers.list = nil
    H.eq(cache.get_selected(), nil, "without a list buffer there is no selection")

    ui_state.buffers.list = buf
    list_window.highlighted_line = nil
    H.eq(cache.get_selected(), nil, "and without a highlighted line either")

    -------------------------------------------------------------------------
    -- The normal case
    -------------------------------------------------------------------------
    show({ "nvim-telescope/telescope.nvim: Find files", "ibhagwan/fzf-lua: Fuzzy: with a colon" })
    list_window.highlighted_line = 1
    local selected = cache.get_selected()
    H.ok(selected, "the highlighted line resolves to a repository")
    H.eq(selected.name, "telescope.nvim", "the right one")
    H.eq(selected.owner.login, "nvim-telescope", "with its owner")

    list_window.highlighted_line = 2
    selected = cache.get_selected()
    H.eq(selected.name, "fzf-lua", "moving the highlight moves the selection")
    -- The line format is `owner/name: description`, and the description may
    -- contain further colons -- the parse has to stop at the first one.
    H.eq(selected.owner.login, "ibhagwan", "a colon inside the description does not confuse the parse")

    -------------------------------------------------------------------------
    -- Every way the resolution can fail is a nil, not a crash
    -------------------------------------------------------------------------
    list_window.highlighted_line = 99
    H.eq(cache.get_selected(), nil, "a highlight past the end of the buffer resolves to nothing")

    show({ "" })
    list_window.highlighted_line = 1
    H.eq(cache.get_selected(), nil, "an empty line resolves to nothing")

    show({ "no separator here" })
    H.eq(cache.get_selected(), nil, "a line that is not `owner/name: ...` resolves to nothing")

    -- The line is on screen, but the cache no longer holds it: the list can be
    -- stale by the time a keymap fires.
    show({ "someone/gone: removed since" })
    H.eq(cache.get_selected(), nil, "a line naming a repository the cache no longer has resolves to nothing")

    -- Right name, wrong owner: both have to match, or two repositories with
    -- the same name would be indistinguishable.
    show({ "someone-else/telescope.nvim: Find files" })
    H.eq(cache.get_selected(), nil, "the owner has to match as well as the name")

    -- A wiped buffer is caught rather than raising out of nvim_buf_get_lines.
    local doomed = vim.api.nvim_create_buf(false, true)
    ui_state.buffers.list = doomed
    vim.api.nvim_buf_delete(doomed, { force = true })
    H.eq(cache.get_selected(), nil, "an invalidated list buffer resolves to nothing")
    ui_state.buffers.list = buf

    -------------------------------------------------------------------------
    -- The relevance snapshot
    -------------------------------------------------------------------------
    cache.clear_relevance_result()
    H.eq(cache.relevance_result, nil, "the snapshot starts empty")

    cache.set({ total_count = #items, items = vim.deepcopy(items) }, true)
    H.ok(cache.relevance_result, "a response marked as original is snapshotted")
    H.eq(#cache.relevance_result.items, 2, "with all of its items")

    -- The snapshot is a deep copy: sorting or filtering the live list must
    -- not reorder the thing it will later be restored from.
    cache.set({ total_count = 1, items = { vim.deepcopy(items[2]) } }, false)
    H.eq(#cache.get().items, 1, "a non-original response replaces the live list")
    H.eq(#cache.relevance_result.items, 2, "and leaves the snapshot untouched")

    do
      local redisplayed, refetched = 0, 0
      H.with_stubs({
        ["reposcope.controllers.list_controller"] = {
          display_repositories = function() redisplayed = redisplayed + 1 end,
        },
        ["reposcope.controllers.provider_controller"] = {
          fetch_readme_for_selected = function() refetched = refetched + 1 end,
        },
      }, {}, function()
        cache.restore_relevance_sorting()
        H.eq(#cache.get().items, 2, "restoring brings the original order back")
        H.eq(cache.get().items[1].name, "telescope.nvim", "in the order the API returned it")
        H.eq(redisplayed, 1, "the list is redrawn")
        H.eq(refetched, 1, "and the preview follows the new selection")

        cache.clear_relevance_result()
        cache.restore_relevance_sorting()
        H.eq(redisplayed, 1, "with no snapshot, restoring is a no-op rather than an error")
      end)
    end

    -------------------------------------------------------------------------
    -- clear() empties in place
    -------------------------------------------------------------------------
    -- Several modules hold `M.repositories` (or its `items`) by reference, so
    -- clearing has to empty the existing tables rather than rebind them.
    cache.set({ total_count = 2, items = vim.deepcopy(items) })
    local held_items = cache.get().items
    local held_list = cache.get().list
    cache.clear()
    H.eq(#held_items, 0, "the items table the caller is holding is the one that got emptied")
    H.eq(#held_list, 0, "and so is the display list")
    H.eq(cache.get().total_count, 0, "the count is reset")
    H.eq(cache.get().items, held_items, "no table was replaced behind a holder's back")
  end)

  ui_state.buffers.list = saved_buf
  list_window.highlighted_line = saved_line
  if vim.api.nvim_buf_is_valid(buf) then vim.api.nvim_buf_delete(buf, { force = true }) end
  cache.clear()
  cache.clear_relevance_result()

  if not ok then error(err, 0) end
end
