local M = {}

function M.debug_win(_win)
      print("[debug]: window number: " .. tostring(_win))
      print("[debug]: win tabpage = ", vim.api.nvim_win_get_tabpage(_win))
      print("[debug]: current tabpage = ", vim.api.nvim_get_current_tabpage())
      print("[debug]: win config", vim.inspect(vim.api.nvim_win_get_config(_win)))
      print("[debug]: buf options", vim.bo[vim.api.nvim_win_get_buf(_win)].buftype)

      for name, win in pairs(require("reposcope.ui.state").windows) do
        if vim.api.nvim_win_is_valid(win) then
          local ok, err = pcall(vim.api.nvim_win_close, win, true)
          if not ok then
            print("[error]: failed to close window [" .. name .. "]: " .. err)
          else
            print("[debug]: closed window [" .. name .. "]")
          end
        else
          print("[debug]: window [" .. name .. "] is not valid")
        end
      end

end

return M
