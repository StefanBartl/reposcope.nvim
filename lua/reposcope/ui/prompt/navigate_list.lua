---@class UIPromptNavigation
---@field navigate_list_in_prompt fun(direction: "up"|"down"): nil Allows navigation within the list directly from the prompt
---@field set_list_to fun(line: number): nil Sets the list's current linr to given line number
local M = {}

local list = require("reposcope.ui.list.repositories")
local ui_state = require("reposcope.state.ui.ui_state")
local debug = require("reposcope.utils.debug")

---Allows navigation within the list directly from the prompt
---@param direction "up"|"down" The direction to navigate ("up" or "down")
function M.navigate_list_in_prompt(direction)
  local total_lines = #vim.api.nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)
  if total_lines == 0 then return end

  list.current_line = list.current_line or 1

  if direction == "up" then
    list.current_line = math.max(list.current_line - 1, 1)
  elseif direction == "down" then
    list.current_line = math.min(list.current_line + 1, total_lines)
  end

  list.update_highlight()
end

---Sets the list's current line to given line number
---@param line string
function M.set_list_to(line)
  if type(line) ~= "number" then
    debug.notify("[reposcope] Type 'number' is required for argument line, passed " .. type(line), 1)
    return
  end

  local total_lines = #vim.api.nvim_buf_get_lines(ui_state.buffers.list, 0, -1, false)

  if line < 1 or line > total_lines then
    debug.notify("[reposcope] Invalid line value: " .. line, 1)
    return
  end

  list.current_line = line
  list.update_highlight()
end

return M
