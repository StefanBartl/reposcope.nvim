---@module 'reposcope.health'
---@brief Health check for the Reposcope plugin

local M = {}

-- Neovim health integration
local health = vim.health or require("health")
-- Dependencies
local config = require("reposcope.config")
local checks = require("reposcope.utils.checks")
local env_has = require("reposcope.utils.env").has

---@return nil
function M.check()
  health.start("Reposcope: plugin healthcheck")

  -- Module Load Check
  if pcall(require, "reposcope.init") then
    health.ok("Core Reposcope modules loaded")
  else
    health.error("Failed to load core modules")
    return
  end

  ---------------------------------------------------------------------------
  -- Request Tool Availability
  ---------------------------------------------------------------------------
  health.info("At least one of: gh, curl, or wget must be available")

  local tools = { "gh", "curl", "wget" }
  for _, bin in ipairs(tools) do
    if checks.has_binary(bin) then
      health.ok(bin .. " is installed")
    else
      health.error(bin .. " is NOT installed")
    end
  end

  if not checks.first_available(tools) then
    health.error("No usable request tool found (gh, curl, or wget)")
  end

  ---------------------------------------------------------------------------
  -- Configured request tool
  ---------------------------------------------------------------------------
  local request_tool = config.get_option("request_tool")
  if vim.tbl_contains(tools, request_tool) then
    health.ok("Configured request tool: " .. request_tool)
  else
    health.warn("Request tool not properly configured: " .. tostring(request_tool))
  end

  ---------------------------------------------------------------------------
  -- Environment variables
  ---------------------------------------------------------------------------
  if env_has("GITHUB_TOKEN") then
    health.ok("GITHUB_TOKEN environment variable set")
  else
    health.warn("GITHUB_TOKEN not set – GitHub API may be rate-limited")
  end
end

return M
