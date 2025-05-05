local M = {}

---Heigh of the ui-prompt
---@type number
M.height = 1

---@type string Unicode
---@private Magnifying glass symbol fpr the ui-prompt
local magnifier = "\u{f002}"

---@type string (concated)
---@private Prefix for the ui-prompt
local prompt_prefix = " " .. magnifier .. "   "

---@type number
---@private Prompt length with respect to special characters in the ui-prompt prefix 
local len = vim.fn.strdisplaywidth(prompt_prefix)

---Set highlight fot the prompt (background)
---@param win number
---@return nil
function M.apply_prompt_highlight(win)
  local ns = vim.api.nvim_create_namespace("reposcope_prompt") --TODO: Auslagern ?
  vim.api.nvim_set_hl(ns, "Normal", { background = '#8092b5', bg = '#252931' })
  vim.api.nvim_win_set_hl_ns(win, ns)
end

---Writes the prompt-prefix and sets the cursor after it
---@param buf number
---@param win number
---@return nil
function M.apply_prompt_prefix(buf, win)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, { prompt_prefix })
  vim.api.nvim_win_set_cursor(win, { 1, len })
end

---Apply the prompt config
---@param buf number
---@param win number
---@return nil
function M.apply_prompt_config(buf, win)
  M.apply_prompt_highlight(win)
  M.apply_prompt_prefix(buf, win)
end

return M
