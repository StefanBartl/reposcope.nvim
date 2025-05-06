-- forward declarations
local github, no_provider

--- @class PromptInput
--- @field on_enter fun(input: string): nil Event function for <CR> keymap in prompt, calls relevant provider search function which makes an api request
--- @field private github fun(input: string): nil Request the github search api with user input
--- @field private no_provider fun(input: string): nil Fallback function which prints the user input
local M = {}

local config = require("reposcope.config")

function M.on_enter(input)
  if config.options.provider == "github" then
    github(input)
  else
     no_provider(input)
  end
end

function github(input)
  --print(input)
  require("reposcope.providers.github.search_repositories").init("", true)
end

function no_provider(input)
  print(input)
  print("[reposcope] Error no provider configured")
end

return M
