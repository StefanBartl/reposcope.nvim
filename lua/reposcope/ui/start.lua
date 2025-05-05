local M = {}
-- TODO: Funktionenen auslagern: FP-Idiom
-- TODO: Fumktionalitäten kapseln, zb set_bg()
table.unpack = table.unpack or unpack
local buffers = require("reposcope.ui.state").buffers
local windows = require("reposcope.ui.state").windows
local previous = require("reposcope.ui.state").previous
local ui_config = require("reposcope.ui.config")
local preview = require("reposcope.ui.preview.preview")
local prompt = require("reposcope.ui.prompt.init")
local prompt_config = require("reposcope.ui.prompt.config")

--TODO: Outsource tp /ui/list
local list_height = math.floor(ui_config.height * 0.6)
local list_row = ui_config.row + preview.height + prompt_config.height + 2
local list_lines = {
    "some/repo_1: Hier steht die Kurzbeschreibung.",
    "some/repo_2: Hier steht die Kurzbeschreibung.",
    "some/repo_3: Hier steht die Kurzbeschreibung"
  }

local legend = "<Esc>: Quit   <Enter>: Search  <C-r>: Readme  <?>: Keybindings"

function M.open_ui()
  local caller_win = vim.api.nvim_get_current_win()
  previous.win = caller_win --REF: shorten this
  local caller_cursor = vim.api.nvim_win_get_cursor(previous.win)
  previous.cursor.row = caller_cursor[1]
  previous.cursor.col =  caller_cursor[2]

  M.open_backgd()
  --M.open_preview()
  prompt.open_prompt()
  M.open_list()
end

function M.open_backgd()
  buffers.backg = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffers.backg, 0, -1, false, {})

  windows.backg = vim.api.nvim_open_win(buffers.backg, false, {
    relative = "editor",
    col = ui_config.col,
    row = ui_config.row,
    height = ui_config.height,
    width = ui_config.width,
    title = "repocope.nvim",
    title_pos = 'center',
    border = "rounded",
    style = "minimal",
    --focusable = false,
    noautocmd = true,
    zindex = 10,
    footer = legend,
    footer_pos = 'center',
  })

end

function M.open_preview()
  buffers.preview = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffers.preview, 0, -1, false, { preview.lines })

  windows.preview = vim.api.nvim_open_win(buffers.preview, false, {
    relative = 'editor',
    col = ui_config.col + ui_config.padding,
    row = ui_config.row + ui_config.padding,
    height = preview.preview_height - ui_config.padding,
    width = ui_config.width - ui_config.padding,
    border = "none",
    title = "Preview",
    title_pos = 'center',
    style = "minimal",
  })

end

function M.open_list()
  buffers.list = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buffers.list, 0, -1, false, list_lines)

  windows.list = vim.api.nvim_open_win(buffers.list, false, {
    relative = "editor",
    row = list_row,
    col = ui_config.col,
    width = ui_config.width,
    height = list_height,
    title = "Repositories",
    title_pos = "left",
    border = "none",
    style = "minimal",
  })
end

function M.close_ui()
  print("[debug-ui-start]: close_ui() started")
  vim.api.nvim_set_current_win(previous.win)
  vim.api.nvim_win_set_cursor(previous.win, { previous.cursor.row, previous.cursor.col })

  for name, win in pairs(require("reposcope.ui.state").windows) do
    if vim.api.nvim_win_is_valid(win) then
      local ok, err = pcall(vim.api.nvim_win_close, win, true)
      if not ok then
        print("[debug-ui-error]: failed to close window [" .. name .. "]: " .. err)
      else
        print("[debug-ui-start]: closed window [" .. name .. "]")
      end
    else
      print("[debug-ui-start]: window [" .. name .. "] is not valid")
    end

  end

--  vim.api.nvim_set_cursor(previous.previous, { previous.previous_cursor.row, previous.previous_cursor.col })
end


-- Keymaps for all Buffers
local map =  require("reposcope.utils.keymap").map_over_bufs
map({ "i", "n" }, "<C-c>", function()
  require("reposcope.ui.start").close_ui()
end, {
    buffers.backg,
    buffers.preview,
    buffers.prompt,
    buffers.list
  }, { silent = true }
)

vim.api.nvim_create_user_command("ReposcopeUIclose", function()
  require("reposcope.ui.start").close_ui()
end, {
   desc = "Close UI"
  }
)

M.open_ui()

return M
