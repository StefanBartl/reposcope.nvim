local M = {}

local ui_config = require("reposcope.ui.config")
local text_utils = require("reposcope.utils.text")
local ui_state = require("reposcope.state.ui")

function M.display()
  local lines = {}
  local json = ui_state.repositories

  if not json or not json.items then
    table.insert(lines, "No results.")
  else
    local total = json.total_count or #json.items
    table.insert(lines, "Total results: " .. total)

    for _, repo in ipairs(json.items) do
      local name = repo.name or "No name"
      name = name .. ": "
      local desc = repo.description or "No description"
      if desc ~= "No description" then
        desc = text_utils.cut_text_for_line(#name, ui_config.width - ui_config.padding, desc)
      end
      table.insert(lines, name .. desc)
    end
  end

  vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", true)
  vim.api.nvim_buf_set_lines(ui_state.buffers.list, 0, -1, false, lines)
  vim.api.nvim_buf_set_option(ui_state.buffers.list, "modifiable", false)
end

return M
