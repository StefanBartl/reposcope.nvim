local health = vim.health or require("health")
local checks = require("reposcope.utils.checks")

return function()
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

  checks.check_env("GITHUB_TOKEN")

  health.ok("reposcope.nvim ready (basic check)")
end
