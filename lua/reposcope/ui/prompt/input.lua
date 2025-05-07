---@desc forward  declarations
local github, no_provider

---@class PromptInput
---@field on_enter fun(input: string): nil Event function for <CR> keymap in prompt, calls relevant provider search function which makes an API request
---@field private github fun(input: string): nil Requests the GitHub search API with user input
---@field private no_provider fun(input: string): nil Fallback function which prints the user input when no provider is configured
local M = {}

local config = require("reposcope.config")
local notify = require("reposcope.utils.debug").notify

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
  --print(input)
  require("reposcope.providers.github.repositories").init("", true)
  local testrepo = require("reposcope.core.json").read_and_parse_file(
    "/media/steve/Depot/MyGithub/reposcope.nvim/debug/gh_test_response.json")
  if not testrepo then
    notify("[reposcope] Error parsing testrepo", vim.log.levels.ERROR)
  else
    require("reposcope.state.repositories").repositories = testrepo
  end
  require("reposcope.ui.list.repositories").display()
end

---Fallback function when no provider is configured
---@param input string The user input in the prompt
function no_provider(input)
  print(input)
  print("[reposcope] Error no provider configured")
end

return M
