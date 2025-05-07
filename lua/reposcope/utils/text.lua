---@class UtilsText
---@field center_text fun(text: string, width: number): string
---@field cut_text_for_line fun(offset: number, width: number, input: string): string
---@field gen_padded_lines fun(height: number, content: string|string[]): string[]
local M = {}

local notify = require("reposcope.utils.debug").notify

---Centers given text input and returns it
---@param text string
---@param width number
function M.center_text(text, width)
  local pad = math.floor((width - #text) / 2)
  return string.rep(" ", math.max(pad, 0)) .. text
end

---Cuts given input to fit in 1 row and postfix it with '...'
---@param offset integer Number of characters before the actual text (e.g. indent)
---@param width integer Total allowed width
---@param input string Text to shorten if needed
function M.cut_text_for_line(offset, width, input)
  local max_length = width - offset - 3
  if #input <= max_length then
    return input
  end
  return string.sub(input, 1, max_length) .. "..."
end

---Pads or trims content to a specific number of lines
---@param height number
---@param content string|string[]
function M.gen_padded_lines(height, content)
  local lines = {}

  -- Normalize to array of strings
  if type(content) == "string" then
    for line in content:gmatch("[^\r\n]+") do
      table.insert(lines, line)
    end
  elseif type(content) == "table" then
    lines = vim.deepcopy(content)
  else
    notify("Content must be a string or a table", vim.log.levels.INFO)
  end

  -- Adjust to desired height
  local result = {}
  for i = 1, height do
    result[i] = lines[i] or ""
  end

  return result
end

return M
