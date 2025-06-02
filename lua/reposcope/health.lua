---@module 'reposcope.health'
---@brief Health module of the Reposcope Plugin
local M = {}

-- Health and Diagnostic Modules
local health = vim.health or require("health")
-- Utility Modules (Error and Validation Checks)
local checks = require("reposcope.utils.checks")


---Performs a health check for reposcope.nvim environment
---@return nil
function M.check()
  health.start("Checking reposcope.nvim environment")

  health.info("At least one of: gh, curl, or wget must be available")

  for _, bin in ipairs({ "gh", "curl", "wget" }) do
    if checks.has_binary(bin) then
      health.ok(bin .. " is installed")
    else
      health.error(bin .. " is NOT installed")
    end
  end

  if not checks.first_available({ "gh", "curl", "wget" }) then
    health.error("No usable request tool found")
  end

  checks.has_env("GITHUB_TOKEN")

  health.ok("reposcope.nvim ready (basic check)")
end

return M
