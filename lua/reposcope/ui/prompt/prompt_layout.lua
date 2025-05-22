---@class UIPromptLayout
---@brief Calculates dynamic window layout for prompt fields.
---@description
---Based on the active prompt fields configured in `prompt_config`, this module calculates
---the dynamic layout to be used by the prompt manager. It determines the width and order
---of each window and assigns the corresponding buffer handles.
---
--- Each returned layout item includes: { name, buffer, width }
---@field build_layout fun(): {name: string, buffer: integer, width: integer, col: integer}[] List of window layouts
local M = {}

-- Config & Utils
local prompt_config = require("reposcope.ui.prompt.prompt_config")
-- State
local ui_state = require("reposcope.state.ui.ui_state")
-- Debugging
local notify = require("reposcope.utils.debug").notify


---Builds a list of window slots for the currently configured prompt fields
---@return {name: string, buffer: integer, width: integer, col: integer}[] List of window layouts
function M.build_layout()
  local fields = prompt_config.get_fields()
  local remaining_width = prompt_config.width
  local current_col = prompt_config.col
  local layout = {}

  local field_count = 0
  for _, f in ipairs(fields) do
    if f ~= "prefix" then
      field_count = field_count + 1
    else
      remaining_width = remaining_width - prompt_config.prefix_win_width
    end
  end

  local dynamic_width = field_count > 0 and math.floor(remaining_width / field_count) or 0

  for _, field in ipairs(fields) do
    local buf = ui_state.buffers.prompt and ui_state.buffers.prompt[field]
    if not buf or not vim.api.nvim_buf_is_valid(buf) then
      notify("[reposcope] Skipped invalid buffer: " .. tostring(field), 4)
      goto continue
    end

    local width = (field == "prefix") and prompt_config.prefix_win_width or dynamic_width

    table.insert(layout, {
      name = field,
      buffer = buf,
      width = width,
      col = current_col,
    })

    current_col = current_col + width
    ::continue::
  end

  return layout
end

return M
