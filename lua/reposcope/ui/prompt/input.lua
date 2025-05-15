---@desc forward  declarations
local github, no_provider

---@class PromptInput
---@field on_enter fun(input: string): nil Event function for <CR> keymap in prompt, calls relevant provider search function which makes an API request
---@field private github fun(input: string): nil Requests the GitHub search API with user input
---@field private no_provider fun(input: string): nil Fallback function which prints the user input when no provider is configured
local M = {}

local config = require("reposcope.config")
local notify = require("reposcope.utils.debug").notify
local state = require("reposcope.state.ui")

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
  require("reposcope.providers.github.repositories").init(input)
  require("reposcope.ui.list.repositories").display()
end

---Fallback function when no provider is configured
---@param input string The user input in the prompt
function no_provider(input)
  notify("[reposcope] Error: no valid provider in /reposcope/configs options table configured: " .. input .. " - default should be 'github'", 4)
end

-- HACK:

--Returns the current text in the prompt buffer without the prefix
---@return string
function M.get_current_prompt_line()
 local text = require("reposcope.state.ui").prompt.actual_text
 return text
end

return M
