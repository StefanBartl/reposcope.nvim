-- TESTS/ui_config_spec.lua — reposcope.ui.config: the shared layout/theme
-- singleton every `*_config` module (background/list/preview/prompt) derives
-- its own geometry from.
--
-- `recompute()` is called from every one of those modules' own load and from
-- `reposcope.init`'s `open_ui()`; `update_layout()` and `update_theme()` are
-- public API with no in-repo caller today -- the module's own top-of-file
-- comment says as much for `update_layout` ("was called by nothing"), the
-- same standing as `protection.is_valid_path`.
--
-- Reloaded in isolation (`package.loaded`, not the live singleton every other
-- `*_config` module already holds its own reference to) so pinning a
-- width/height or switching the theme here cannot leak into whatever those
-- modules read for the rest of the suite.

return function(H)
  local saved_columns, saved_lines = vim.o.columns, vim.o.lines

  H.with_stubs(nil, { "reposcope.ui.config" }, function()
    -- recompute(): a fraction of the editor, re-centred -----------------------
    vim.o.columns, vim.o.lines = 200, 50
    local cfg = require("reposcope.ui.config")
    cfg.recompute()
    H.eq(cfg.width, math.floor(200 * cfg.WIDTH_FRACTION), "width is a fraction of the editor's columns")
    H.eq(cfg.height, math.floor(50 * cfg.HEIGHT_FRACTION), "height is a fraction of the editor's lines")
    H.eq(cfg.col, math.floor((200 - cfg.width) / 2), "col centres the width")
    H.eq(cfg.row, math.floor((50 - cfg.height) / 2), "row centres the height")

    vim.o.columns, vim.o.lines = 300, 80
    cfg.recompute()
    H.eq(cfg.width, math.floor(300 * cfg.WIDTH_FRACTION), "a later recompute() tracks a resized editor")
    H.eq(cfg.col, math.floor((300 - cfg.width) / 2), "and re-centres around it")

    -- update_layout(): width/height are a pin that survives a later recompute --
    cfg.update_layout(120, 40)
    H.eq(cfg.width, 120, "an explicit width applies immediately")
    H.eq(cfg.height, 40, "so does an explicit height")
    H.eq(cfg.col, math.floor((300 - 120) / 2), "col is re-centred around the pinned width")

    vim.o.columns, vim.o.lines = 400, 100
    cfg.recompute()
    H.eq(cfg.width, 120, "a bare recompute() afterwards keeps the pinned width")
    H.eq(cfg.height, 40, "and the pinned height")
    H.eq(cfg.col, math.floor((400 - 120) / 2), "but col/row still re-centre against the new editor size")
    H.eq(cfg.row, math.floor((100 - 40) / 2), "row too")

    -- ...but update_layout()'s own col/row are a one-off, not a second pin:
    -- they are applied *after* recompute() has already re-centred, and
    -- nothing remembers them the way explicit_width/height are remembered.
    cfg.update_layout(nil, nil, 5, 7)
    H.eq(cfg.col, 5, "an explicit col from update_layout() applies immediately")
    H.eq(cfg.row, 7, "so does an explicit row")
    cfg.recompute()
    H.eq(cfg.col, math.floor((400 - 120) / 2), "a later recompute() overwrites the one-off col with the centred value")
    H.eq(cfg.row, math.floor((100 - 40) / 2), "the one-off row does not survive either")

    -- update_theme(): dark/light are the two named palettes, "custom" is a
    -- documented no-op, anything else is reported and left unchanged --------
    local dark_bg, dark_accent = cfg.colortheme.background, cfg.colortheme.accent_1
    cfg.update_theme("light")
    H.eq(cfg.colortheme.background, "#FFFFFF", "light switches to the documented light background")
    H.ok(cfg.colortheme.background ~= dark_bg, "and it really did change")

    cfg.update_theme("dark")
    H.eq(cfg.colortheme.background, dark_bg, "dark restores the original background")
    H.eq(cfg.colortheme.accent_1, dark_accent, "and the rest of the dark palette")

    cfg.update_theme("light")
    local light_bg, light_accent = cfg.colortheme.background, cfg.colortheme.accent_1
    cfg.update_theme("custom")
    H.eq(
      cfg.colortheme.background,
      light_bg,
      '"custom" is a documented no-op -- it leaves the current background as-is'
    )
    H.eq(cfg.colortheme.accent_1, light_accent, "and the rest of the current palette too")

    local notes = {}
    H.with_stubs({
      ["reposcope.utils.debug"] = { notify = function(msg) notes[#notes + 1] = msg end },
    }, { "reposcope.ui.config" }, function()
      local nested = require("reposcope.ui.config")
      nested.update_theme("neon")
      H.eq(#notes, 1, "an unknown theme name is reported once")
      H.contains(notes[1], "Invalid theme", "naming the problem")
      H.contains(notes[1], "neon", "and the value that was rejected")
    end)

    -- A theme switch reaches the derived *_config modules' colors, not just
    -- `ui.config.colortheme` itself (ERR-53): each one re-derives its colors
    -- from the active colortheme on every `recompute()`, the same way it
    -- already re-derives its geometry. Reloaded together with this isolated
    -- `cfg`, so they bind to it instead of the real shared singleton.
    H.with_stubs(nil, {
      "reposcope.ui.list.list_config",
      "reposcope.ui.background.background_config",
      "reposcope.ui.preview.preview_config",
    }, function()
      cfg.update_theme("light")
      local list_config = require("reposcope.ui.list.list_config")
      local background_config = require("reposcope.ui.background.background_config")
      local preview_config = require("reposcope.ui.preview.preview_config")

      list_config.recompute()
      background_config.recompute()
      preview_config.recompute()

      H.eq(list_config.highlight_color, cfg.colortheme.accent_1, "list_config's highlight color tracks the theme")
      H.eq(list_config.normal_color, cfg.colortheme.text, "and its normal color")
      H.eq(background_config.color_bg, cfg.colortheme.background, "background_config's color tracks it too")
      H.eq(preview_config.highlight_color, cfg.colortheme.background, "as does preview_config's highlight color")
      H.eq(preview_config.normal_color, cfg.colortheme.text, "and its normal color")

      -- update_colors() pins survive a later recompute(), same as
      -- update_layout()'s width/height.
      list_config.update_colors("#123456", nil)
      cfg.update_theme("dark")
      list_config.recompute()
      H.eq(list_config.highlight_color, "#123456", "a pinned color is not overwritten by a later theme switch")
      H.eq(list_config.normal_color, cfg.colortheme.text, "an unpinned one still tracks it")
    end)
  end)

  vim.o.columns, vim.o.lines = saved_columns, saved_lines
end
