-- TESTS/config_spec.lua — reposcope.config: what `setup()` does to the option
-- table, including the part that differs from the sibling plugins.

return function(H)
  local config = require("reposcope.config")
  local DEFAULTS = require("reposcope.config.DEFAULTS")

  -- Pick a scalar key that actually exists, so this spec does not have to be
  -- edited every time the option surface grows.
  local key, original
  for k, v in pairs(DEFAULTS) do
    if type(v) == "string" or type(v) == "number" or type(v) == "boolean" then
      key, original = k, v
      break
    end
  end
  H.ok(key, "DEFAULTS has at least one scalar option to test against")

  -- Defaults ------------------------------------------------------------------
  H.eq(config.options[key], original, "the option table starts at the defaults")

  -- A user value wins ---------------------------------------------------------
  local changed = (type(original) == "boolean") and not original
    or (type(original) == "number") and (original + 1)
    or (tostring(original) .. "-changed")
  config.setup({ [key] = changed })
  H.eq(config.options[key], changed, "a user value wins")
  H.eq(DEFAULTS[key], original, "and DEFAULTS itself is not mutated")

  -- setup() is cumulative -----------------------------------------------------
  -- Worth stating outright, because it is the opposite of what the sibling
  -- plugins do. They rebuild from `deepcopy(DEFAULTS)` on every call, so a
  -- second `setup({})` resets everything. Here the merge target is the *current*
  -- table:
  --
  --   M.options = vim.tbl_deep_extend("force", M.options, opts)
  --
  -- so a later call can only add to or overwrite what an earlier one set, never
  -- unset it. That is fine for the normal single-setup() path and surprising for
  -- anything that reconfigures at runtime; pinned here so a change to it is a
  -- deliberate one rather than a silent one.
  config.setup({})
  H.eq(config.options[key], changed, "setup({}) does NOT reset -- the merge accumulates")

  config.setup({ [key] = original })
  H.eq(config.options[key], original, "restoring takes an explicit value")

  -- Invalid input -------------------------------------------------------------
  -- A non-table is reported and ignored rather than raising: setup() runs from
  -- a user's config, where a crash costs them the rest of their startup.
  local ok = pcall(config.setup, "not a table")
  H.ok(ok, "a non-table argument does not raise")
  H.eq(config.options[key], original, "and changes nothing")
end
