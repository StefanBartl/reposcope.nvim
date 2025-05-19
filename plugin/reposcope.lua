---@class ReposcopeHealthRegistrar
---@brief Registers the health check function for the Reposcope plugin.
---@description
---This module automatically registers the health check function for Reposcope
---if the health module is available in the user's Neovim configuration. 
---It ensures that the plugin's health status can be verified via the `:checkhealth` command.
---
---If the health module is not available (older Neovim versions), it gracefully skips registration.

-- Check if the health module is available (Neovim 0.8+)
if vim.health and vim.health.registry then
  ---Registers the health check for Reposcope in the Neovim health system
  vim.health.registry["reposcope"] = function()
    require("reposcope.health").check()
  end
end
