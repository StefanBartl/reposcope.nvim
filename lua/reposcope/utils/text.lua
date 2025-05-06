--- @class UtilsText
--- @field center_text fun(text: string, width: number): string Centers given text input and returns it
--- @field cut_text_for_line fun(offset: number, width: number, input: string): string Cuts given input to fit in 1 row and postfix it with '...'
local M = {}

function M.center_text(text, width)
  local pad = math.floor((width - #text) / 2)
  return string.rep(" ", math.max(pad, 0)) .. text
end

---@param offset integer Number of characters to account for before the actual text (e.g. prefix or indent)
---@param width integer Maximum allowed total width of the line (e.g. window width)
---@param input string The text string to be shortened if necessary
function M.cut_text_for_line(offset, width, input)
  local max_length = width - offset - 3
  if #input <= max_length then
    return input
  end
  return string.sub(input, 0, max_length) .. "..."
end

return M
