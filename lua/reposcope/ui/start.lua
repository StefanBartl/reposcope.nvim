local M = {}
-- TODO: Funktionenen auslagern: FP-Idiom
-- TODO: Fumktionalitäten kapseln, zb set_bg()

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
local magnifier = "\u{f002}"
local prompt_prefix = " " .. magnifier .. "   "
local prompt_len = vim.fn.strdisplaywidth(prompt_prefix)

local list_height = math.floor(height * 0.6)
local list_row = row + preview_height + prompt_height + 2
local list_lines = {
    "some/repo_1: Hier steht die Kurzbeschreibung.",
    "some/repo_2: Hier steht die Kurzbeschreibung.",
    "some/repo_3: Hier steht die Kurzbeschreibung"
  }

local legend = "<Esc>: Quit   <Enter>: Search  <C-r>: Readme  <?>: Keybindings"

M.state = {
  buffers = {
    back_buf = nil,
    preview_buf = nil,
    prompt_buf = nil,
    list_buf = nil,
  },
  windows = {
    backg_win = nil,
    preview_win  = nil,
    prompt_win = nil,
    list_win = nil,
  }
}

function M.open_ui()
  --M.open_backg_window()
  --M.open_preview()
  M.open_prompt()
  --M.open_list()
end

function M.open_backg_window()
  M.state.buffers.back_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.back_buf, 0, -1, false, {})

  M.state.windows.backg_win = vim.api.nvim_open_win(M.state.buffers.back_buf, false, {
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
    zindex = 10,
    footer = legend,
    footer_pos = 'center',
  })

end

function M.open_preview()
  M.state.buffers.pre_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.pre_buf, 0, -1, false, preview_lines)

  M.state.windows.preview_win = vim.api.nvim_open_win(M.state.buffers.pre_buf, false, {
    relative = 'editor',
    col = col + padding,
    row = row + padding,
    height = preview_height - padding,
    width = width - padding,
    border = "none",
    title = "Preview",
    title_pos = 'center',
    style = "minimal",
  })

end

function M.open_prompt()
  M.state.buffers.prompt_buf = vim.api.nvim_create_buf(false, true)

  local ns = vim.api.nvim_create_namespace("reposcope_prompt")
  vim.api.nvim_set_hl(ns, "Normal", { background = '#8092b5', bg = '#252931' })

  M.state.windows.prompt_win = vim.api.nvim_open_win(M.state.buffers.prompt_buf, true, {
   relative = "editor",
   row = row + preview_height,
   col = col + 1,
   width = width - 2,
   height = prompt_height,
   border = "single",
   title = "Search Repositories",
   title_pos = "center",
   style = 'minimal',
  })

  vim.api.nvim_win_set_hl_ns(M.state.windows.prompt_win, ns)
  vim.api.nvim_buf_set_lines(M.state.buffers.prompt_buf, 0, -1, false, { prompt_prefix })
  vim.api.nvim_win_set_cursor(M.state.windows.prompt_win, { 1, prompt_len })


  -- === Block Left before prompt begin ====
  vim.keymap.set("i", "<Left>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_len then
      return ""  -- blockiere Bewegung in den statischen Bereich
    else
      return "<Left>"
    end
  end, { buffer = M.state.buffers.prompt_buf, expr = true, silent = true })

  -- === Block Backspace before prompt begin ===
  vim.keymap.set("i", "<BS>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_len then
      return ""  -- nichts löschen
    else
      return "<BS>"
    end
  end, { buffer = M.state.buffers.prompt_buf, expr = true, silent = true })

  -- === Block Word back before prompt begin ===
  vim.keymap.set("i", "<C-w>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_len then
      return ""  -- nichts löschen
    else
      return "<C-w>"
    end
  end, { buffer = M.state.buffers.prompt_buf, expr = true, silent = true })

  -- === Overwrite Home to prompt begin ===
  vim.keymap.set("i", "<Home>", function()
    return string.format("<Cmd>call cursor(1, %d)<CR>", prompt_len + 1)
  end, { buffer = M.state.buffers.prompt_buf, expr = true, silent = true })

  -- === Overwrite '0' ===
  vim.keymap.set("n", "0", function()
    vim.api.nvim_win_set_cursor(0, { 1, prompt_len })
  end, { buffer = M.state.buffers.prompt_buf, silent = true })


  vim.keymap.set("i", "<CR>", function()
    local input = vim.api.nvim_get_current_line()
    vim.api.nvim_buf_delete(M.state.buffers.prompt_buf, { force = true })
    on_enter(input)
  end, { buffer = M.state.buffers.prompt_buf, silent = true })

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

function M.open_list()
  M.state.buffers.repo_buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(M.state.buffers.repo_buf, 0, -1, false, list_lines)

  M.state.windows.list_win = vim.api.nvim_open_win(M.state.buffers.repo_buf, false, {
    relative = "editor",
    row = list_row,
    col = col,
    width = width,
    height = list_height,
    title = "Repositories",
    title_pos = "left",
    border = "none",
    style = "minimal",
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
