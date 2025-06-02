---@module 'reposcope.utils.text_utils'
---@brief Utilities for centering, cutting, and formatting textual content

---@class TextUtils : TextUtilsModule
local M = {}

-- Debugging Utility
local notify = require("reposcope.utils.debug").notify


---Centers given text input and returns it, splitting lines without breaking words
---@param text string The text to be centered
---@param width number The maximum width for centering
---@return string[]
function M.center_text(text, width)
  local lines = {}

  if #text > width then
    local start = 1

    while start <= #text do
      local segment = text:sub(start, start + width - 1)

      -- Check if the segment is at full width and the next character is not a space
      if #segment == width and text:sub(start + width, start + width):match("%S") then
        local last_space = segment:match(".*()%s")
        if last_space then
          segment = text:sub(start, start + last_space - 1)
          start = start + last_space -- Move past the last space
        else
          start = start + width -- Move to the next segment
        end
      else
        start = start + #segment
      end

      -- Center the segment by adding padding
      local pad = math.floor((width - #segment) / 2)
      table.insert(lines, string.rep(" ", math.max(pad, 0)) .. segment)
    end

    return lines
  end

  -- If the text fits within the width, center it directly
  local pad = math.floor((width - #text) / 2)
  return { string.rep(" ", math.max(pad, 0)) .. text }
end


---Centers an array of text lines within a specified width
---@param lines string[] List of text lines to be centered
---@param width number The maximum width for centering
---@return string[]
function M.center_text_lines(lines, width)
  local centered_lines = {}

  for _, line in ipairs(lines) do
    for _, centered in ipairs(M.center_text(line, width)) do
      table.insert(centered_lines, centered)
    end
  end

  return centered_lines
end


---Cuts given input to fit in 1 row and postfix it with '...'
---@param offset integer Number of characters before the actual text (e.g. indent)
---@param width integer Total allowed width
---@param input string Text to shorten if needed
---@return string
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
---@return string[]
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

  local result = {}
  for i = 1, height do
    result[i] = lines[i] or ""
  end

  return result
end

return M
