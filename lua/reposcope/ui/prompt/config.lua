
--- @class UIPromptConfig
--- @field apply_prompt_highlight fun(win: number): nil Set highlight fot the prompt (background)
--- @field apply_prompt_prefix fun(buf: number, win: number): nil Writes the prompt-prefix and sets the cursor after it 
--- @field apply_prompt_config fun(buf: number, win: number): nil Apply the prompt config
--- @field private magnifier string # Unicode U+F002 magnifying glass symbol for prompt
--- @field private prompt_prefix string Prefix for the prompt
--- @field len number Prompt length with respect to special characters in the ui-prompt prefix 
--- @field height number Height of the prompt
local M = {}

local magnifier = "\u{f002}"
local prompt_prefix = " " .. magnifier .. "   "
M.len = vim.fn.strdisplaywidth(prompt_prefix)
M.height = 1

function M.apply_prompt_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_prompt") --TODO: Auslagern ?
  vim.api.nvim_set_hl(ns, "Normal", { background = '#8092b5', bg = '#252931' })
  vim.api.nvim_win_set_hl_ns(win, ns)
end

function M.apply_prompt_prefix(buf, win)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prompt_prefix })
  vim.api.nvim_win_set_cursor(win, { 1, M.len })
end

function M.apply_prompt_config(buf, win)
  M.apply_prompt_highlight(win)
  M.apply_prompt_prefix(buf, win)
end

return M
