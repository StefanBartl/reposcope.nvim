-- TESTS/run.lua — headless test runner for reposcope.nvim.
--
-- Run from the repo root:
--   nvim --headless -u NONE -c "set rtp+=." -l TESTS/run.lua
--
-- lib.nvim and ui.nvim both have to be reachable: several reposcope
-- modules require them at module load (status_view.lua's `ui.kit`
-- notably, exercised directly by TESTS/status_view_spec.lua). The runner
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

-- Ordered so a failure points at the smallest layer first.
local specs = {
  "core_utils_spec.lua",
  "query_builder_spec.lua",
  "repository_cache_spec.lua",
  "config_spec.lua",
  "favorites_state_spec.lua",
  "status_view_spec.lua",
  "preview_image_spec.lua",
  "hover_spec.lua",
  "readme_urls_spec.lua",
  "list_window_spec.lua",
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
