local M = {}

function M.info_from_win(_win)
      print("[debug]: window number: " .. tostring(_win))
      print("[debug]: win tabpage = ", vim.api.nvim_win_get_tabpage(_win))
      print("[debug]: current tabpage = ", vim.api.nvim_get_current_tabpage())
      print("[debug]: win config", vim.inspect(vim.api.nvim_win_get_config(_win)))
      print("[debug]: buf options", vim.bo[vim.api.nvim_win_get_buf(_win)].buftype)
end

return M
