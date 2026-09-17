-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/init_spec.lua — the plugin's own entry points.
--
-- Two halves. `setup()` is driven against stubs, so each of its optional
-- steps can be switched off and observed. `open_ui()`/`close_ui()` are run
-- for real, with no stubs at all: Neovim opens floating windows perfectly
-- well headless, and a lifecycle whose only test is "the mocks were called"
-- would not have caught a window that fails to close.

return function(H)
  ---------------------------------------------------------------------------
  -- setup()
  ---------------------------------------------------------------------------
  ---@param fn fun(init: table, env: table): nil
  local function with_init(fn)
    local env = { setup_opts = nil, resolved = 0, keymaps = {}, warmed = 0, hover = 0, options = {} }

    H.with_stubs({
      ["reposcope.config"] = {
        options = env.options,
        setup = function(opts) env.setup_opts = opts end,
        get_option = function(key) return env.options[key] end,
      },
      ["reposcope.utils.checks"] = {
        resolve_request_tool = function() env.resolved = env.resolved + 1 end,
        has_binary = function() return true end,
        first_available = function() return "curl" end,
      },
      ["reposcope.bindings.keymaps"] = {
        set_user_keymaps = function(cfg, opts) env.keymaps[#env.keymaps + 1] = { cfg = cfg, opts = opts } end,
        set_ui_keymaps = function() end,
        unset_ui_keymaps = function() end,
      },
      ["reposcope.cache.readme_cache"] = {
        warm_ram_from_file_cache = function()
          env.warmed = env.warmed + 1
          return 0
        end,
      },
      ["reposcope.hover"] = {
        setup = function()
          env.hover = env.hover + 1
          return true
        end,
      },
    }, { "reposcope.init" }, function() fn(require("reposcope.init"), env) end)
  end

  with_init(function(init, env)
    env.options.keymaps = { open = "<leader>rs", close = "<leader>rc" }
    env.options.keymap_opts = { silent = true }
    env.options.hover = true

    init.setup({ provider = "gitlab" })

    H.eq(env.setup_opts.provider, "gitlab", "the user's options are handed to config.setup")
    H.eq(env.resolved, 1, "the request tool is resolved once")
    H.eq(#env.keymaps, 1, "the two global keymaps are registered")
    H.eq(env.keymaps[1].cfg.open, "<leader>rs", "from the configuration")
    H.eq(env.keymaps[1].opts.silent, true, "with the configured options")
    -- The file cache survives a restart; without this, a fresh session still
    -- pays a disk read on the first navigation to each repository.
    H.eq(env.warmed, 1, "the file cache is warmed into RAM")
    H.eq(env.hover, 1, "and the hover.nvim source is contributed")
  end)

  with_init(function(init, env)
    init.setup()
    H.eq(type(env.setup_opts), "table", "setup() with no arguments still configures, with an empty table")
    H.eq(next(env.setup_opts), nil, "which is empty")
  end)

  -- Both integrations are opt-out, and `false` is the documented way to do it.
  with_init(function(init, env)
    env.options.keymaps = false
    env.options.hover = false
    init.setup({})
    H.eq(#env.keymaps, 0, "`keymaps = false` registers no global keymaps at all")
    H.eq(env.hover, 0, "and `hover = false` contributes nothing to hover.nvim")
    H.eq(env.warmed, 1, "while the cache warm-up still happens -- it is not an integration")
  end)

  ---------------------------------------------------------------------------
  -- open_ui() / close_ui(), for real
  ---------------------------------------------------------------------------
  do
    local config = require("reposcope.config")
    local ui_state = require("reposcope.state.ui.ui_state")
    local list_window = require("reposcope.ui.list.list_window")
    local prompt_config = require("reposcope.ui.prompt.prompt_config")
    local saved_fields = vim.deepcopy(prompt_config.get_fields())

    local ok, err = pcall(function()
      -- A real prompt layout, so the prompt windows are actually built.
      config.setup({ prompt_fields = { "prefix", "keywords", "owner" } })

      local windows_before = #vim.api.nvim_list_wins()
      local caller_win = vim.api.nvim_get_current_win()

      local init = require("reposcope.init")
      init.open_ui()

      -- Where the user was is remembered, so closing can put them back.
      H.eq(ui_state.get_invocation_win(), caller_win, "the caller's window is captured before anything opens")

      local bufs = ui_state.get_buffers()
      H.ok(bufs and #bufs > 0, "opening the UI creates buffers")
      local wins = ui_state.get_windows()
      H.ok(wins and #wins >= 3, "and at least the background, list and preview windows")
      H.ok(#vim.api.nvim_list_wins() > windows_before, "which really exist in the editor")

      H.ok(ui_state.buffers.list, "the list buffer is registered")
      H.ok(ui_state.buffers.preview, "the preview buffer too")
      H.eq(type(ui_state.buffers.prompt), "table", "and the prompt buffers as a per-field map")

      -- Each window is a reposcope:// buffer, which is what the QuitPre
      -- autocmd keys off.
      local named = 0
      for _, win in ipairs(wins) do
        if vim.api.nvim_win_is_valid(win) then
          local name = vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win))
          if name:find("^reposcope://") then named = named + 1 end
        end
      end
      H.ok(named >= 3, "every Reposcope window holds a reposcope:// buffer")

      local list_buf = ui_state.buffers.list
      local preview_buf = ui_state.buffers.preview

      init.close_ui()

      H.falsy(vim.api.nvim_buf_is_valid(list_buf), "closing the UI deletes the list buffer")
      H.falsy(vim.api.nvim_buf_is_valid(preview_buf), "and the preview buffer")
      H.eq(#vim.api.nvim_list_wins(), windows_before, "leaving the editor with the windows it started with")
      H.eq(vim.api.nvim_get_current_win(), caller_win, "and the cursor back where it was")
      H.eq(
        ui_state.list.last_selected_line,
        list_window.highlighted_line,
        "the selected row is remembered for next time"
      )

      -- Documented, not a defect: `close_ui` deletes the buffers but leaves
      -- their handles in `ui_state.buffers`. Nothing reads a stale handle --
      -- `create_named_buffer` and `get_valid_buffer` both check validity
      -- first -- but "the UI is closed" is not the same as "the state is
      -- empty", and a reader of this table has to know that.
      H.ok(ui_state.buffers.list, "the state still holds the (now dead) handle afterwards")
      H.eq(ui_state.get_valid_buffer("list"), nil, "which every reader is expected to validate before use")

      -- Reopening from that state has to work, i.e. the stale handles must
      -- not confuse the second round.
      init.open_ui()
      H.ok(ui_state.get_valid_buffer("list"), "reopening builds a fresh list buffer")
      H.ok(vim.api.nvim_buf_is_valid(ui_state.buffers.preview), "and a fresh preview buffer")
      init.close_ui()
      H.eq(#vim.api.nvim_list_wins(), windows_before, "and closing again leaves nothing behind")

      -- Closing twice must not raise: `:q` in a Reposcope window fires the
      -- QuitPre handler, which can race a manual `:Reposcope close`.
      local ok_twice = pcall(init.close_ui)
      H.ok(ok_twice, "closing an already-closed UI is harmless")
    end)

    ui_state.reset()
    prompt_config.set_fields(saved_fields)
    if not ok then error(err, 0) end
  end
end
