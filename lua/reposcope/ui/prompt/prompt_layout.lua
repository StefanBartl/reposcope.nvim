---@module 'reposcope.ui.prompt.prompt_layout'
---@brief Calculates dynamic window layout for prompt fields.
---@description
---Based on the active prompt fields configured in `prompt_config`, this module calculates
---the dynamic layout to be used by the prompt manager. It determines the width and order
---of each window and assigns the corresponding buffer handles.

---@class UIPromptLayout : UIPromptLayoutModule
local M = {}

local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
-- Config & Utils
local prompt_config = require("reposcope.ui.prompt.prompt_config")
local get_fields = require("reposcope.ui.prompt.prompt_config").get_fields
-- State
local ui_state = require("reposcope.state.ui.ui_state")
-- Debugging
local notify = require("reposcope.utils.debug").notify


---Builds a list of window slots for the currently configured prompt fields
---@return {name: string, buffer: integer, width: integer, col: integer}[] List of window layouts
function M.build_layout()
  local fields = get_fields()
  local buffers = ui_state.buffers.prompt or {}
  local config = prompt_config

  local remaining_width = config.width
  local current_col = config.col

  ---@type {name: string, buffer: integer, width: integer, col: integer}[]
  local layout = {}

  -- Count dynamic (non-prefix) fields and subtract fixed prefix width
  local dynamic_count = 0
  for i = 1, #fields do
    if fields[i] ~= "prefix" then
      dynamic_count = dynamic_count + 1
    else
      remaining_width = remaining_width - config.prefix_win_width
    end
  end

  local dynamic_width = dynamic_count > 0 and math.floor(remaining_width / dynamic_count) or 0

  -- Build layout structure
  for i = 1, #fields do
    local field = fields[i]
    local buf = buffers[field]

    if type(buf) ~= "number" or not nvim_buf_is_valid(buf) then
      notify("[reposcope] Skipped invalid buffer: " .. tostring(field), 4)
    else
      local width = (field == "prefix") and config.prefix_win_width or dynamic_width
      layout[#layout + 1] = {
        name = field,
        buffer = buf,
        width = width,
        col = current_col,
      }
      current_col = current_col + width
    end
  end

  return layout
end

return M
