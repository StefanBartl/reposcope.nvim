---@module 'reposcope.ui.actions.filter_prompt'
---@brief Opens a floating input for filtering repository list entries
---@description
--- This module shows a `kit.input()` prompt to allow users to filter the
--- currently displayed repository list by text. The actual filtering logic
--- is delegated to `ui.actions.filter_repos.apply_filter` (same as
--- `:Reposcope filter`) so both entry points share one implementation and
--- one "current filter" tracking point.
local M = {}

local apply_filter = require("reposcope.ui.actions.filter_repos").apply_filter
local kit = require("lib.nvim.ui.kit")

---Opens a floating input window to enter a filter query.
---@return nil
function M.prompt_filter()
  kit.input({
    title = " Filter Repositories ",
    width = 40,
    on_submit = function(input)
      if not input or input == "" then return end
      apply_filter(input)
    end,
  })
end

return M
