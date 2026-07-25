---@module 'reposcope.ui.actions.filter_prompt'
---@brief Opens a floating input for filtering repository list entries
---@description
--- This module shows a `vim.ui.input()` prompt to allow users to filter the
--- currently displayed repository list by text. The actual filtering logic
--- is delegated to `ui.actions.filter_repos.apply_filter` (same as
--- `:Reposcope filter`) so both entry points share one implementation and
--- one "current filter" tracking point.
local M = {}

local apply_filter = require("reposcope.ui.actions.filter_repos").apply_filter


---Opens a floating input window to enter a filter query.
---@return nil
function M.prompt_filter()
  local buf = vim.api.nvim_create_buf(false, true) -- scratch, listed=false
  local width = 40
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Filter Repositories ",
    title_pos = "center",
  })

  -- Setup buffer options
  vim.bo[buf].buftype = "prompt"
  vim.fn.prompt_setprompt(buf, "> ")

  -- Handle <CR> to read input and apply filter
  vim.fn.prompt_setcallback(buf, function(input)
    vim.api.nvim_win_close(win, true)
    if not input or input == "" then return end

    apply_filter(input)
  end)

  vim.cmd("startinsert")
end

return M
