local M = {}
local buffers = require("reposcope.ui.state").buffers
local previous = require("reposcope.ui.state").previous
local background = require("reposcope.ui.background")
local preview = require("reposcope.ui.preview.init")
local list = require("reposcope.ui.list.init")
local prompt = require("reposcope.ui.prompt.init")
local keymaps =  require("reposcope.keymaps")

function M.open_ui()
  --DEBUG: Neccesary?
  local caller_win = vim.api.nvim_get_current_win()
  previous.win = caller_win --REF: shorten this
  local caller_cursor = vim.api.nvim_win_get_cursor(previous.win)
  previous.cursor.row = caller_cursor[1]
  previous.cursor.col =  caller_cursor[2]

  background.open_backgd()
  preview.open_preview()
  prompt.open_prompt()
  list.open_list()

  keymaps.set_prompt_keymaps()
end

function M.close_ui()
  -- set focus back to caller position
  if vim.api.nvim_win_is_valid(previous.win) then
    vim.api.nvim_set_current_win(previous.win)
    vim.api.nvim_win_set_cursor(previous.win, {
      previous.cursor.row,
      previous.cursor.col,
    })
  end

  -- close all windows
  for _, win in ipairs(vim.api.nvim_list_wins()) do
    local ok_buf, buf = pcall(vim.api.nvim_win_get_buf, win)
    if ok_buf and vim.api.nvim_buf_is_valid(buf) then
      local name = vim.api.nvim_buf_get_name(buf)
      if name:find("^reposcope://") then
        vim.api.nvim_win_close(win, true)
      end
    end
  end

   keymaps.unset_prompt_keymaps()
end



-- Keymaps for all Buffers NOTE: move
local map =  require("reposcope.keymaps").map_over_bufs
map({ "i", "n" }, "<C-c>", function()
  require("reposcope.ui.start").close_ui()
end, {
    buffers.backg,
    buffers.preview,
    buffers.prompt,
    buffers.list
  }, { silent = true }
)

--NOTE: move
vim.api.nvim_create_user_command("ReposcopeUIclose", function(_)
  local ok, err = pcall(function()
    require("reposcope.ui.start").close_ui()
  end)
  if not ok then
    vim.notify("Fehler beim Schließen der UI: " .. err, vim.log.levels.ERROR)
  end
end, {
  desc = "Close the Reposcope UI",
})

M.open_ui()

return M
