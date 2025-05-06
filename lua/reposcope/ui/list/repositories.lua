local M = {}

local ui_config = require("reposcope.ui.config")
local text_utils = require("reposcope.utils.text")
local state = require("reposcope.ui.state")

function M.display(json)
  local lines = {}
  local total = json.total_count
  table.insert(lines, "Total results: " .. total)

  for _, repo in ipairs(json.items) do
    local name = repo.name or "No name"
    name = name .. ": "
    local desc = repo.description or "No description"
    if not desc == "No description" then
      desc = text_utils.cut_text_for_line(#name, ui_config.width - ui_config.padding, desc)
    end
    table.insert(lines, "- " .. name .. desc)
  end

  if #lines == 0 then
    table.insert(lines, "No results.")
  end

  vim.api.nvim_buf_set_option(state.buffers.list, "modifiable", true)
  vim.api.nvim_buf_set_lines(state.buffers.list, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(state.buffers.list, "modifiable", false)
end

return M
