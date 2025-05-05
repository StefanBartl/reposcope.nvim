local M = {}
local prompt_config = require("reposcope.ui.prompt.config")

--BUG: In normal mode there also be some protection
--Provide functionality to protect cursor from getting before prompt prefix
---@param buf number
---@param prompt_len number
---@return nil
function M.protect(buf, prompt_len)

  -- === Block Left before prompt begin ====
  vim.keymap.set("i", "<Left>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_config.len then
      return ""  -- blockiere Bewegung in den statischen Bereich
    else
      return "<Left>"
    end
  end, { buffer = buf, expr = true, silent = true })

  -- === Block Backspace before prompt begin ===
  vim.keymap.set("i", "<BS>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_config.prompt_len then
      return ""  -- nichts löschen
    else
      return "<BS>"
    end
  end, { buffer = buf, expr = true, silent = true })

  -- === Block Word back before prompt begin === NOTE: throwed error in debugging esc 
  --[[
  vim.keymap.set("i", "<C-w>", function()
    local _, prompt_col = unpack(vim.api.nvim_win_get_cursor(0))
    if prompt_col <= prompt_len then
      return ""  -- nichts löschen
    else
      return "<C-w>"
    end
  end, { buffer = buf, expr = true, silent = true })
   ]]--


  -- === Overwrite Home to prompt begin ===
  vim.keymap.set("i", "<Home>", function()
    return string.format("<Cmd>call cursor(1, %d)<CR>", prompt_len + 1)
  end, { buffer = buf, expr = true, silent = true })

  -- === Overwrite '0' ===
  vim.keymap.set("n", "0", function()
    vim.api.nvim_win_set_cursor(0, { 1, prompt_len })
  end, { buffer = buf, silent = true })


end

return M
