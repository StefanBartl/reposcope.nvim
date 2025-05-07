--- @class UIProtectPrompt
--- @field protect fun(buf: number, prefix_len: number): nil Provide functionality to protect cursor from getting before prompt prefix
local M = {}

local prompt_config = require("reposcope.ui.prompt.config")

--BUG: In normal mode there also be some protection

function M.protect(buf, prefix_len)

  -- === Block Left before prompt begin ====
  vim.keymap.set("i", "<Left>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_config.prefix_len then
      return ""  -- blockiere Bewegung in den statischen Bereich
    else
      return "<Left>"
    end
  end, { buffer = buf, expr = true, silent = true })

  -- === Block Backspace before prompt begin ===
  vim.keymap.set("i", "<BS>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_config.prefix_len then
      return ""  -- nichts löschen
    else
      return "<BS>"
    end
  end, { buffer = buf, expr = true, silent = true })

  -- === Overwrite Home to prompt begin ===
  vim.keymap.set("i", "<Home>", function()
    return string.format("<Cmd>call cursor(1, %d)<CR>", prefix_len + 1)
  end, { buffer = buf, expr = true, silent = true })

  -- === Overwrite '0' ===
  vim.keymap.set("n", "0", function()
    vim.api.nvim_win_set_cursor(0, { 1, prefix_len })
  end, { buffer = buf, silent = true })


end

return M
