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

---Returns the current text in the prompt buffer without the prefix
---@return string
function M.get_current_prompt_line()
  local prompt_buf = state.buffers.prompt

  if not prompt_buf then
    vim.notify("[reposcope] Error: Prompt buffer is not initialized or not loaded.", vim.log.levels.ERROR)
    return ""
  end

  local current_buf = vim.api.nvim_get_current_buf()
  local current_win = vim.api.nvim_get_current_win()
  local temp = false

  if current_buf ~= prompt_buf then
    temp = true
    vim.api.nvim_set_current_buf(prompt_buf)
  end

  local input = vim.api.nvim_get_current_line() or ""
  local sanitized_query = input:gsub("[\u{f002}]", ""):gsub("^%s*(.-)%s*$", "%1")

  if temp then
    vim.api.nvim_set_current_buf(current_buf)
    vim.api.nvim_set_current_win(current_win)
  end

  return sanitized_query
end

return M
