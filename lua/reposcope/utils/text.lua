---@class UtilsText
---@field center_text fun(text: string, width: number): string[] Centers given text input and returns it, splitting lines without breaking words
---@field cut_text_for_line fun(offset: number, width: number, input: string): string Centers given text input and returns it
---@field gen_padded_lines fun(height: number, content: string|string[]): string[] Centers given text input and returns it
local M = {}

local notify = require("reposcope.utils.debug").notify

---Centers given text input and returns it, splitting lines without breaking words
---@param text string The text to be centered
---@param width number The maximum width for centering
---@return string[] List of centered text lines (split if necessary)
function M.center_text(text, width)
  local lines = {} -- Resulting list of centered text lines

  -- Check if the text is longer than the specified width
  if #text > width then
    local start = 1

    -- Loop to split text into lines
    while start <= #text do
      -- Extract a segment of the text with the specified width
      local segment = text:sub(start, start + width - 1)

      -- Check if the segment is at full width and the next character is not a space
      if #segment == width and text:sub(start + width, start + width):match("%S") then
        -- Try to find the last space in the segment
        local last_space = segment:match(".*()%s")
        if last_space then
          -- Adjust the segment to end at the last space
          segment = text:sub(start, start + last_space - 1)
          -- Start the next line directly after the last word
          start = start + last_space -- Move past the last space
        else
          -- If no space is found, force a split (word too long)
          start = start + width -- Move to the next segment
        end
      else
        -- If the segment fits or ends perfectly, move to the next
        start = start + #segment
      end

      -- Center the segment by adding padding
      local pad = math.floor((width - #segment) / 2)
      table.insert(lines, string.rep(" ", math.max(pad, 0)) .. segment)
    end

    return lines -- Return the list of centered text lines
  end

  -- If the text fits within the width, center it directly
  local pad = math.floor((width - #text) / 2)
  return { string.rep(" ", math.max(pad, 0)) .. text }
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
    notify("Content must be a string or a table", 2)
  end

  -- Adjust to desired height
  local result = {}
  for i = 1, height do
    result[i] = lines[i] or ""
  end

  return result
end

return M
