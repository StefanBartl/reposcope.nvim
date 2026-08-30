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
  local has_any = false
  local has = checks.has_binary

  for i = 1, #tools do
    local bin = tools[i]
    if has(bin) then
      health.ok(bin .. " is installed")
      has_any = true
    else
      health.error(bin .. " is NOT installed")
    end
  end

  if not has_any then health.error("No usable request tool found (gh, curl, or wget)") end
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

  ---------------------------------------------------------------------------
  -- README image preview (optional, images.nvim)
  ---------------------------------------------------------------------------
  local ok_images, images_config = pcall(require, "images.config")
  if not ok_images then
    health.info("images.nvim not installed – the README image preview is unavailable (nothing else is affected)")
  else
    local ok_cfg, cfg = pcall(images_config.get)
    local remote = ok_cfg and cfg and cfg.display and cfg.display.remote or {}

    if remote.enabled then
      -- The download cap lives in images.nvim, not here: the transfer happens
      -- inside `images.remote.fetch`, which reads its own config. Reporting
      -- the effective value is the only honest thing this check can do about
      -- size — a cap applied on this side would refuse to draw bytes that
      -- have already been paid for.
      local mb = (remote.max_bytes or (20 * 1024 * 1024)) / 1024 / 1024
      health.ok(("images.nvim remote images enabled (download cap %.1f MB)"):format(mb))
      if mb > 2 then
        health.info(
          "README images measured 232 kB on average, 925 kB worst case; lowering "
            .. "`display.remote.max_bytes` in images.nvim caps what one preview can pull"
        )
      end
    else
      health.info(
        "images.nvim installed but remote images are off – set `display.remote.enabled = true` "
          .. "there to use the README image preview"
      )
    end
  end

  require("lib.nvim.bindings.usercmd.composer").checkhealth("Reposcope")
end

return M
