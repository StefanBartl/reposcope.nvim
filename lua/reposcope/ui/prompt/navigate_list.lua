---@class UIPromptNavigation
---@field navigate_list_in_prompt fun(direction: "up"|"down"): nil Allows navigation within the list directly from the prompt
local M = {}

local list = require("reposcope.ui.list.repositories")
local state = require("reposcope.state.ui")

---Allows navigation within the list directly from the prompt
---@param direction "up"|"down" The direction to navigate ("up" or "down")
function M.navigate_list_in_prompt(direction)
  local total_lines = #vim.api.nvim_buf_get_lines(state.buffers.list, 0, -1, false)
  if total_lines == 0 then return end

  list.current_line = list.current_line or 1

  if direction == "up" then
    list.current_line = math.max(list.current_line - 1, 1)
  elseif direction == "down" then
    list.current_line = math.min(list.current_line + 1, total_lines)
  end

  list.update_highlight()
end

return M
