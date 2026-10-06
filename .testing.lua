-- .testing.lua -- configuration of testing.nvim for this project.
-- Written by `testing migrate`; edit freely (it is never overwritten). Every key is optional; the
-- keys are documented in testing.nvim's docs/CONFIG.md. Loading this file executes it (same trust
-- as running the specs).
return {
  -- Lua module root of the project.
  plugin = "reposcope",
  -- How the spec files are run: "auto" = sniffed per file, "h" = on the project's own TESTS/harness.lua,
  -- "script" = a self-running script in its own process.
  dialect = "h",
  -- Dependencies (directory names) put on the runtimepath: $<NAME>_DIR, .deps/<name>, ../<name>,
  -- stdpath('data')/lazy/<name>.
  deps = { "lib.nvim", "ui.nvim" },
  -- "none" = all specs in one nvim, "file" = one nvim per spec file
  -- (nothing leaks from one file into the next).
  -- "file" here because the specs call setup() and open floating windows, buffers and highlight
  -- groups they never close (148 state findings in one shared editor); one editor per file keeps
  -- that from reaching the next file.
  isolated = "file",
  -- Environment variables the specs read; a child editor inherits an allowlist only (never secrets).
  env_allow = { "MAGICK_*" },
  -- Guards (docs/GUARDS.md): the suite is clean for all of them, so every one is an error.
  guards = {
    fs = "error",
    state = "error",
    scheduled_error = "error",
    prompt = "error",
    deprecation = "error",
    process_net = "error",
  },
  -- What the guards let through on purpose. Paths are relative to the project root (the runner is
  -- started from it by scripts/test.sh).
  guard_allow = {
    fs = {
      -- The specs create and remove these fixture directories inside the repository on purpose
      -- (one per spec that needs a cache, session or log file on disk).
      "TESTS/.fixture-clone",
      "TESTS/.fixture-config_options",
      "TESTS/.fixture-favorites_state",
      "TESTS/.fixture-metrics",
      "TESTS/.fixture-protection",
      "TESTS/.fixture-query_stats",
      "TESTS/.fixture-readme_cache",
      "TESTS/.fixture-session_state",
    },
  },
}
