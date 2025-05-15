---@class UIProtectPrompt
---@field protect fun(buf: number): nil Provide functionality to protect cursor from getting before prompt prefix
local M = {}

--- Protects cursor movement in the prompt window (Normal Mode)
--- @param buf number The buffer ID of the prompt
function M.protect(buf)
  -- Block left movement (h, <Left>) at the start of the second line
  vim.keymap.set("n", "h", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1], cursor[2]

    -- Block movement if at the start of the second line
    if row == 2 and col == 0 then
      return "" -- Prevent movement
    else
      return "h" -- Allow normal movement
    end
  end, { buffer = buf, expr = true, silent = true })

  vim.keymap.set("n", "<Left>", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row, col = cursor[1], cursor[2]

    -- Block movement if at the start of the second line
    if row == 2 and col == 0 then
      return "" -- Prevent movement
    else
      return "<Left>" -- Allow normal movement
    end
  end, { buffer = buf, expr = true, silent = true })

  -- Block upward movement (k) in the second line
  vim.keymap.set("n", "k", function()
    local cursor = vim.api.nvim_win_get_cursor(0)
    local row = cursor[1]

    -- Prevent moving up if already in the second line
    if row == 2 then
      return "" -- Prevent movement
    else
      return "k" -- Allow normal movement
    end
  end, { buffer = buf, expr = true, silent = true })

  -- Redirect gg to always jump to the start of the second line
  vim.keymap.set("n", "gg", function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- Always second line, start
  end, { buffer = buf, silent = true })

  -- Redirect 0 to always jump to the start of the second line
  vim.keymap.set("n", "0", function()
    vim.api.nvim_win_set_cursor(0, { 2, 0 }) -- Always second line, start
  end, { buffer = buf, silent = true })
end

return M
