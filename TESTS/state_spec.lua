-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/state_spec.lua — the three in-memory state modules: the request
-- registry that gates every network call, the prompt's per-field text, and
-- the UI's buffer/window/invocation bookkeeping.

return function(H)
  ---------------------------------------------------------------------------
  -- requests_state: register -> active -> ended
  ---------------------------------------------------------------------------
  do
    local rs = require("reposcope.state.requests_state")
    rs.clear_all_requests()

    H.falsy(rs.is_registered("u"), "an unknown UUID is not registered")
    H.falsy(rs.is_request_active("u"), "and not active")

    rs.register_request("u")
    H.ok(rs.is_registered("u"), "registering makes it known")
    H.falsy(rs.is_request_active("u"), "but not yet active -- that is the two-phase gate the managers rely on")

    rs.start_request("u")
    H.ok(rs.is_request_active("u"), "starting marks it active")
    H.ok(rs.is_registered("u"), "and it stays registered")

    -- Starting twice must not resurrect anything: `start_request` only
    -- promotes a UUID that is registered-and-inactive.
    rs.start_request("u")
    H.ok(rs.is_request_active("u"), "starting an already-active request is a no-op")

    rs.end_request("u")
    H.falsy(rs.is_registered("u"), "ending forgets it entirely")
    H.falsy(rs.is_request_active("u"), "so it is no longer active either")

    -- Starting a UUID that was never registered must not create one --
    -- otherwise the "is this request ours" check would be meaningless.
    rs.start_request("never-registered")
    H.falsy(rs.is_registered("never-registered"), "starting an unregistered UUID registers nothing")

    -- Degenerate identifiers are refused rather than stored.
    for _, bad in ipairs({ "", 42, {}, true }) do
      rs.register_request(bad)
      H.falsy(rs.is_registered(bad), "a non-string/empty UUID is refused: " .. tostring(bad))
    end
    rs.register_request(nil)
    H.falsy(rs.is_registered(nil), "as is nil")

    rs.register_request("a")
    rs.register_request("b")
    rs.start_request("b")
    rs.clear_all_requests()
    H.falsy(rs.is_registered("a"), "clear_all_requests forgets the inactive ones")
    H.falsy(rs.is_registered("b"), "and the active ones")
  end

  ---------------------------------------------------------------------------
  -- prompt_state: per-field text
  ---------------------------------------------------------------------------
  do
    local ps = require("reposcope.state.ui.prompt_state")
    local saved = vim.deepcopy(ps.input)

    H.eq(ps.get_field_text("never-set"), "", "an unset field reads as the empty string, not nil")

    ps.set_field_text("keywords", "telescope")
    H.eq(ps.get_field_text("keywords"), "telescope", "what is written is what is read")

    ps.set_field_text("keywords", "")
    H.eq(ps.get_field_text("keywords"), "", "clearing a field is a normal write")

    -- Only string/string pairs are accepted: a nil here would otherwise make
    -- a field silently vanish from `prompt_input.collect()`.
    ps.set_field_text("owner", "someone")
    ps.set_field_text("owner", nil)
    H.eq(ps.get_field_text("owner"), "someone", "a nil value is ignored rather than clearing the field")
    ps.set_field_text("owner", 42)
    H.eq(ps.get_field_text("owner"), "someone", "so is a non-string")
    ps.set_field_text(nil, "x")
    ps.set_field_text(42, "x")
    H.eq(ps.get_field_text(42), "", "and a non-string field name stores nothing")

    ps.input = saved
  end

  ---------------------------------------------------------------------------
  -- ui_state: handles, invocation context, and the reset surface
  ---------------------------------------------------------------------------
  do
    local ui_state = require("reposcope.state.ui.ui_state")
    local saved_buffers = vim.deepcopy(ui_state.buffers)
    local saved_windows = vim.deepcopy(ui_state.windows)

    ui_state.reset()
    H.eq(ui_state.get_buffers(), nil, "an empty state reports no buffers at all, rather than an empty list")
    H.eq(ui_state.get_windows(), nil, "and no windows")

    local buf = vim.api.nvim_create_buf(false, true)
    ui_state.buffers.preview = buf
    H.eq(ui_state.get_valid_buffer("preview"), buf, "a live buffer is handed back")
    H.eq(#ui_state.get_buffers(), 1, "and counted")

    -- The prompt slot holds a *map* of field name to buffer, not a single
    -- handle, so the collector has to descend into it.
    local a = vim.api.nvim_create_buf(false, true)
    local b = vim.api.nvim_create_buf(false, true)
    ui_state.buffers.prompt = { keywords = a, owner = b }
    H.eq(#ui_state.get_buffers(), 3, "a nested table of handles is flattened into the list")

    vim.api.nvim_buf_delete(buf, { force = true })
    H.eq(ui_state.get_valid_buffer("preview"), nil, "a wiped buffer is reported as gone")
    H.eq(ui_state.get_valid_buffer("never-used"), nil, "as is a slot that was never filled")

    ui_state.windows.preview = 999999
    H.eq(#ui_state.get_windows(), 1, "window handles are collected the same way")

    -- Resetting one table must leave the others alone.
    ui_state.reset("windows")
    H.eq(ui_state.get_windows(), nil, "resetting windows empties them")
    H.ok(ui_state.get_buffers(), "and leaves the buffers alone")

    ui_state.reset("buffers")
    H.eq(ui_state.get_buffers(), nil, "resetting buffers empties them too")

    -- An unrecognised argument resets nothing (and is reported); it must not
    -- be treated like `nil`, which resets everything.
    ui_state.buffers.list = a
    ui_state.reset("nonsense")
    H.ok(ui_state.get_buffers(), "an invalid reset target changes nothing")
    ui_state.reset()

    vim.api.nvim_buf_delete(a, { force = true })
    vim.api.nvim_buf_delete(b, { force = true })

    -- Invocation context: where the user was when the UI opened.
    ui_state.capture_invocation_state()
    H.eq(ui_state.get_invocation_win(), vim.api.nvim_get_current_win(), "the caller's window is captured")
    local cursor = ui_state.get_invocation_cursor()
    H.eq(type(cursor.row), "number", "together with the cursor row")
    H.eq(type(cursor.col), "number", "and column")

    ui_state.reset("invocation")
    H.eq(ui_state.get_invocation_win(), nil, "which the invocation reset clears")
    H.eq(ui_state.get_invocation_cursor().row, nil, "row included")

    -- The "has the list ever been filled" flag is boolean-only.
    ui_state.set_list_populated(true)
    H.ok(ui_state.is_list_populated(), "the populated flag can be set")
    ui_state.set_list_populated("yes")
    H.ok(ui_state.is_list_populated(), "a non-boolean is refused rather than coerced")
    ui_state.set_list_populated(false)
    H.falsy(ui_state.is_list_populated(), "and it can be cleared")

    for k, v in pairs(saved_buffers) do
      ui_state.buffers[k] = v
    end
    for k, v in pairs(saved_windows) do
      ui_state.windows[k] = v
    end
  end
end
