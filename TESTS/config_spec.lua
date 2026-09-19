-- TESTS/config_spec.lua — reposcope.config: what `setup()` does to the option
-- table.

return function(H)
  local config = require("reposcope.config")
  local DEFAULTS = require("reposcope.config.DEFAULTS")

  -- Pick a scalar key that actually exists, so this spec does not have to be
  -- edited every time the option surface grows. Skips the three token fields:
  -- like `clone.std_dir`, config/init.lua re-resolves them from the
  -- environment right after requiring DEFAULTS (LUA-06), so config.options[key]
  -- can legitimately differ from DEFAULTS[key] for those -- and on a machine
  -- with GITHUB_TOKEN set, it does.
  local env_resolved = { github_token = true, gitlab_token = true, codeberg_token = true }
  local key, original
  for k, v in pairs(DEFAULTS) do
    if not env_resolved[k] and (type(v) == "string" or type(v) == "number" or type(v) == "boolean") then
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

  -- setup() rebuilds from defaults ---------------------------------------------
  -- The merge target is a fresh table on every call:
  --
  --   M.options = vim.tbl_deep_extend("force", {}, defaults, opts)
  --
  -- so a later call cannot inherit anything an earlier one set -- `setup({})`
  -- is the documented way to get back to the defaults, and it actually does.
  config.setup({})
  H.eq(config.options[key], original, "setup({}) resets to the defaults")

  config.setup({ [key] = changed })
  H.eq(config.options[key], changed, "a later setup() call still applies its own value")

  config.setup({ [key] = original })
  H.eq(config.options[key], original, "restoring takes an explicit value")

  -- Invalid input -------------------------------------------------------------
  -- A non-table is reported and ignored rather than raising: setup() runs from
  -- a user's config, where a crash costs them the rest of their startup.
  local ok = pcall(config.setup, "not a table")
  H.ok(ok, "a non-table argument does not raise")
  H.eq(config.options[key], original, "and changes nothing")
end
