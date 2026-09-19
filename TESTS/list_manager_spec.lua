-- TESTS/list_manager_spec.lua — reposcope.ui.list.list_manager.update_list's
-- deferred buffer write.
--
-- `update_list` schedules its `nvim_buf_set_lines` call rather than running it
-- synchronously, so the list buffer can have been deleted (the whole UI
-- closed while a search was still in flight) by the time the callback
-- actually runs. `vim.schedule` is replaced with a synchronous, pcall-wrapped
-- stand-in so a regression here fails the assertion instead of only printing
-- to `:messages` where a test's own `pcall` around a spec never sees it.

return function(H)
  local ui_state = require("reposcope.state.ui.ui_state")
  local saved_list_buf = ui_state.buffers.list

  local highlight_calls = 0
  local notes = {}
  local scheduled_errors = {}
  local injected = {}

  local original_schedule = vim.schedule
  vim.schedule = function(fn)
    local ok, err = pcall(fn)
    if not ok then scheduled_errors[#scheduled_errors + 1] = err end
  end

  local ok_run, err_run = pcall(function()
    H.with_stubs({
      ["reposcope.ui.list.list_window"] = {
        open_window = function() return true end,
        close_window = function() end,
        highlight_selected = function() highlight_calls = highlight_calls + 1 end,
      },
      ["reposcope.ui.preview.preview_manager"] = {
        inject_content = function(_, lines) injected[#injected + 1] = lines end,
        update_preview = function() end,
      },
      ["reposcope.ui.preview.preview_config"] = { width = 60 },
      ["reposcope.cache.repository_cache"] = { get_selected = function() return nil end },
      ["reposcope.utils.debug"] = {
        notify = function(msg) notes[#notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.ui.list.list_manager" }, function()
      local list_manager = require("reposcope.ui.list.list_manager")

      -----------------------------------------------------------------------
      -- The common case: the buffer is still there when the callback fires
      -----------------------------------------------------------------------
      local buf = vim.api.nvim_create_buf(false, true)
      ui_state.buffers.list = buf

      local ok = list_manager.update_list({ "owner/repo" })
      H.ok(ok, "update_list reports success while the write is scheduled")
      H.eq(#scheduled_errors, 0, "the deferred write does not raise")
      H.eq(highlight_calls, 1, "and highlights the selection")
      H.eq(vim.api.nvim_buf_get_lines(buf, 0, -1, false)[1], "owner/repo", "the buffer holds the new lines")

      vim.api.nvim_buf_delete(buf, { force = true })

      -----------------------------------------------------------------------
      -- The UI closes (buffer deleted) before the scheduled write runs (LUA-13)
      -----------------------------------------------------------------------
      local buf2 = vim.api.nvim_create_buf(false, true)
      ui_state.buffers.list = buf2
      vim.api.nvim_buf_delete(buf2, { force = true }) -- already gone by the time the write would land

      highlight_calls = 0
      local ok2 = list_manager.update_list({ "owner/repo" })
      H.ok(ok2, "update_list still reports success -- the write just never lands")
      H.eq(#scheduled_errors, 0, "a deleted buffer is skipped instead of raising")
      H.eq(highlight_calls, 0, "and never reaches highlight_selected either")

      -----------------------------------------------------------------------
      -- The "no results" message is centered for the current preview width,
      -- not one frozen at require time (PERF-92)
      -----------------------------------------------------------------------
      local buf3 = vim.api.nvim_create_buf(false, true)
      ui_state.buffers.list = buf3

      local preview_config = require("reposcope.ui.preview.preview_config")

      preview_config.width = 60
      list_manager.update_list({})
      local at_60 = table.concat(injected[#injected], "\n")

      preview_config.width = 20
      list_manager.update_list({})
      local at_20 = table.concat(injected[#injected], "\n")

      H.ok(at_60 ~= at_20, "the message is re-centered for the width current at call time, not at require time")

      vim.api.nvim_buf_delete(buf3, { force = true })
    end)
  end)

  vim.schedule = original_schedule
  ui_state.buffers.list = saved_list_buf
  if not ok_run then error(err_run, 0) end
end
