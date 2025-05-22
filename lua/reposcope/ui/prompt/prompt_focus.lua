---@class UIPromptFocus
---@brief Manages cursor focus logic within the prompt input UI
---@description
--- This module ensures correct focus behavior for the prompt input UI.
--- It provides utilities to set the cursor to the first interactive field
--- (skipping non-focusable elements like the prefix window).
---@field focus_first_input fun(): nil Sets focus to the first interactive prompt field

local M = {}

-- UI State
local ui_state = require("reposcope.state.ui.ui_state")
-- Prompt config
local prompt_config = require("reposcope.ui.prompt.prompt_config")


--- Focuses the first focusable prompt input window (skips prefix).
---@return nil
function M.focus_first_input()
  local fields = prompt_config.get_fields()
  for _, field in ipairs(fields) do
    local win = ui_state.windows.prompt and ui_state.windows.prompt[field]
    if win and vim.api.nvim_win_is_valid(win) then
      local config = vim.api.nvim_win_get_config(win)
      if config.focusable then
        vim.api.nvim_set_current_win(win)
        vim.cmd("startinsert")
        return
      end
    end
  end
end

return M
