--- @class UtilsText
--- @field center_text fun(text: string, width: number): string Centers given text input and returns it
local M = {}

function M.center_text(text, width)
  local pad = math.floor((width - #text) / 2)
  return string.rep(" ", math.max(pad, 0)) .. text
end

return M
