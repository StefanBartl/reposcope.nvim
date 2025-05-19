---@desc forward  declarations
local github, no_provider

---@class PromptInput
---@field on_enter fun(input: string): nil Event function for <CR> keymap in prompt, calls relevant provider search function which makes an API request
---@field private github fun(input: string): nil Requests the GitHub search API with user input
---@field private no_provider fun(input: string): nil Fallback function which prints the user input when no provider is configured
local M = {}

-- Configuration (Global Configuration)
local config = require("reposcope.config")
-- Debugging Utility
local notify = require("reposcope.utils.debug").notify
-- Providers (GitHub Repositories)
local gh_repositories = require("reposcope.providers.github.repositories")
-- List Controller (Managing List UI)
local list_controller = require("reposcope.controllers.list_controller")


---Handles the <CR> keymap in the prompt, calling the relevant provider
---@param input string The user input in the prompt
function M.on_enter(input)
  if config.options.provider == "github" then
    github(input)
  else
    no_provider(input)
  end
end

---Requests the GitHub search API with user input
---@param input string The user input in the prompt
function github(input)
  gh_repositories.init(input)
  list_controller.display_repositories()
end

---Fallback function when no provider is configured
---@param input string The user input in the prompt
function no_provider(input)
  notify("[reposcope] Error: no valid provider in /reposcope/configs options table configured: " .. input .. " - default should be 'github'", 4)
end

return M
