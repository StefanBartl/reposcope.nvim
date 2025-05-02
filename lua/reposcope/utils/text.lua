local M = {}

function M.center_text(text, width)
  local pad = math.floor((width - #text) / 2)
  return string.rep(" ", math.max(pad, 0)) .. text
end

return M
