local M = {}

local width = math.floor(vim.o.columns * 0.6) -- total
local height = math.floor(vim.o.lines * 0.8) -- total
local padding = 1
local col = math.floor((vim.o.columns - width) / 2) -- center
local row = math.floor((vim.o.lines - height) / 2) -- center

local preview_lines = {
   "Ab hier Previewline",
   "Lorem preview ips",
   "Lorem pre",
   "ipsum ipsm",
   "fünfte previw"
}
local preview_height = vim.tbl_count(preview_lines)

local prompt_height = 1
local on_enter = function(input)
  vim.notify("[reposcope.nvim] You searched: " .. input)
end

local list_height = math.floor(height * 0.6)
local list_row = row + preview_height + prompt_height + 2
local list_lines = {
    "some/repo_1: Hier steht die Kurzbeschreibung.",
    "some/repo_2: Hier steht die Kurzbeschreibung.",
    "some/repo_3: Hier steht die Kurzbeschreibung"
  }

local legend = "<Esc>: Quit   <Enter>: Search  <C-r> get Readme  <C-xx> xx"

M.state = {
  buffers = {
    back_buf = nil,
    preview_buf = nil,
    prompt_buf = nil,
    list_buf = nil,
    legend_buf = nil
  },
  windows = {
    back_win = nil,
    preview_win  = nil,
    prompt_win = nil,
    list_win = nil,
    legend_win = nil
  }
}

function M.open_ui()
  M.open_back_window()
  --M.open_preview()
  --M.open_prompt()
  --M.open_list()
  M.open_legend()
end

function M.open_back_window()
  M.state.buffers.back_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.back_buf, 0, -1, false, {})

  M.state.back_win = vim.api.nvim_open_win(M.state.buffers.back_buf, false, {
    relative = "editor",
    col = col,
    row = row,
    height = height,
    width = width,
    title = "repocope.nvim",
    title_pos = 'center',
    border = "rounded",
    style = "minimal",
    --focusable = false,
    noautocmd = true,
    zindex = 10
  })

end

function M.open_preview()
  M.state.buffers.pre_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.pre_buf, 0, -1, false, preview_lines)

  M.state.preview_win = vim.api.nvim_open_win(M.state.buffers.pre_buf, false, {
    relative = 'editor',
    col = col + padding,
    row = row + padding,
    height = preview_height - padding,
    width = width - padding,
    border = "none",
    title = "Preview",
    title_pos = 'center',
    style = "minimal"
  })

end

function M.open_prompt()
  M.state.buffers.prompt_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.prompt_buf, 0, -1, false, { "" })

  M.state.prompt_win = vim.api.nvim_open_win(M.state.buffers.prompt_buf, true, {
    relative = "editor",
    row = row + preview_height,
    col = col + 1,
    width = width - 2,
    height = prompt_height,
    border = "single",
    title = "Search Repositories",
    title_pos = "center",
    style = 'minimal'
  })

  vim.bo[M.state.buffers.prompt_buf].buftype = "prompt"
  vim.fn.prompt_setprompt(M.state.buffers.prompt_buf, "> ")

  vim.keymap.set("i", "<CR>", function()
    local input = vim.api.nvim_get_current_line()
    vim.api.nvim_buf_delete(M.state.buffers.prompt_buf, { force = true }) -- Eingabepuffer schließen
    on_enter(input)  -- Callback ausführen
  end, { buffer = M.state.buffers.prompt_buf, silent = true })
end

function M.open_list()
  M.state.buffers.repo_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.repo_buf, 0, -1, false, list_lines)

  M.state.list_win = vim.api.nvim_open_win(M.state.buffers.repo_buf, false, {
    relative = "editor",
    row = list_row,
    col = col,
    width = width,
    height = list_height,
    title = "Repositories",
    title_pos = "left",
    border = "none",
    style = "minimal"
  })
 end

function M.open_legend()
  M.state.buffers.legend_buf = vim.api.nvim_create_buf(false, true)
  local legend = require("reposcope.utils.text").center_text(legend, width)
  vim.api.nvim_buf_set_lines(M.state.buffers.legend_buf, 0, -1, false, { legend })

  M.state.windows.legend_win = vim.api.nvim_open_win(M.state.buffers.legend_buf, false, {
    relative = 'editor',
    col = col,
    row = row + height - 1,
    height = 1,
    width = width,
    border = "single",
    title = "Command Legend",
    title_pos = 'center',
    style = 'minimal'
  })

end

function M.close_ui()
  for _, win in ipairs(M.state.windows) do
    if vim.api.nvim_win_is_valid(win) then
      vim.api.nvim_win_close(win, true)
    end
  end
end

-- Keymaps for all Buffers
local map =  require("reposcope.utils.keymap").map_over_bufs
map({ "i", "n" }, "<Esc>", function()
  require("reposcope.ui.start").close_ui()
end, {
    M.state.buffers.back_buf,
    M.state.buffers.preview_buf,
    M.state.buffers.prompt_buf,
    M.state.buffers.list_buf
  }, { silent = true }
)


M.open_ui()

return M
