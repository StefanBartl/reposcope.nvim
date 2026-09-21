-- TESTS/run.lua — headless test runner for reposcope.nvim.
--
-- Run from the repo root:
--   nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
--
-- lib.nvim and ui.nvim both have to be reachable: several reposcope
-- modules require them at module load (dashboard_view.lua's `ui.kit`
-- notably, exercised directly by TESTS/dashboard_view_spec.lua). The runner
-- puts a sibling checkout of each on the runtimepath, or whatever
-- $LIB_NVIM_PATH/$UI_NVIM_PATH point at.

local dir = debug.getinfo(1, "S").source:sub(2):match("(.*[/\\])") or "./"

---@param env_var string
---@param sibling_name string
---@param marker_dir string # e.g. "lib" or "ui" -- checked as "<candidate>/lua/<marker_dir>"
local function add_dep(env_var, sibling_name, marker_dir)
  local candidates = {}
  local env_val = vim.env[env_var]
  if env_val and env_val ~= "" then candidates[#candidates + 1] = env_val end
  candidates[#candidates + 1] = dir .. "../../" .. sibling_name
  candidates[#candidates + 1] = vim.fn.stdpath("data") .. "/lazy/" .. sibling_name

  for _, path in ipairs(candidates) do
    local norm = vim.fs.normalize(path)
    if vim.fn.isdirectory(norm .. "/lua/" .. marker_dir) == 1 then
      vim.opt.rtp:append(norm)
      package.path = table.concat({
        norm .. "/lua/?.lua",
        norm .. "/lua/?/init.lua",
        package.path,
      }, ";")
      return true
    end
  end
  return false
end

add_dep("LIB_NVIM_PATH", "lib.nvim", "lib")
add_dep("UI_NVIM_PATH", "ui.nvim", "ui")

if not pcall(require, "lib.lua.tables") then
  print("FAIL  cannot locate lib.nvim (a runtime dependency of reposcope.nvim).")
  print("      Set $LIB_NVIM_PATH, or check it out next to this repo.")
  os.exit(1)
end

if not pcall(require, "ui.kit") then
  print("FAIL  cannot locate ui.nvim (a runtime dependency of reposcope.nvim).")
  print("      Set $UI_NVIM_PATH, or check it out next to this repo.")
  os.exit(1)
end

local H = dofile(dir .. "harness.lua")

-- Ordered so a failure points at the smallest layer first: pure helpers,
-- then config/state, then the network stack, then the provider layer built on
-- it, and only afterwards the controllers, bindings and UI-facing actions.
local specs = {
  -- Leaf utilities
  "core_utils_spec.lua",
  "utils_spec.lua",
  "encoding_text_spec.lua",
  "protection_spec.lua",
  -- Configuration and state
  "config_spec.lua",
  "config_options_spec.lua",
  "state_spec.lua",
  "session_state_spec.lua",
  "query_stats_spec.lua",
  "favorites_state_spec.lua",
  -- Caches
  "repository_cache_spec.lua",
  "repository_cache_selection_spec.lua",
  "readme_cache_spec.lua",
  -- Network stack (no process is ever spawned; see TESTS/README.md)
  "request_tools_spec.lua",
  "http_client_spec.lua",
  -- Provider layer
  "query_builder_spec.lua",
  "readme_urls_spec.lua",
  "repository_fetcher_spec.lua",
  "readme_fetcher_spec.lua",
  "readme_manager_spec.lua",
  "repository_manager_spec.lua",
  "clone_spec.lua",
  -- Controllers
  "controllers_spec.lua",
  "provider_controller_spec.lua",
  -- Metrics and the repo-maintenance commands
  "metrics_spec.lua",
  "repos_util_spec.lua",
  -- Bindings, health and UI-facing actions
  "bindings_spec.lua",
  "health_spec.lua",
  "actions_spec.lua",
  "readme_views_spec.lua",
  "dashboard_view_spec.lua",
  "preview_image_spec.lua",
  "hover_spec.lua",
  "list_manager_spec.lua",
  "list_window_spec.lua",
  "ui_config_spec.lua",
  -- Last on purpose: the only spec that opens the real UI, so it is the one
  -- that would leave stray windows behind if it failed halfway.
  "init_spec.lua",
}

local failed = 0
for _, name in ipairs(specs) do
  local run = dofile(dir .. name)
  local ok, err = pcall(run, H)
  if ok then
    print(("ok    %s"):format(name))
  else
    failed = failed + 1
    print(("FAIL  %s\n      %s"):format(name, tostring(err)))
  end
end

if failed > 0 then
  print(("\n%d spec(s) failed"):format(failed))
  os.exit(1)
end

print("\nREPOSCOPE_TESTS_OK")
