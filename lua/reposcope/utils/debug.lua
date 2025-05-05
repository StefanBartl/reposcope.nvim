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

-- Diese Funktion in deinem Modul hinzufügen und manuell testen
function M.test_window()
  print("=== Window Lifecycle Test ===")

  -- Aktuelles Fenster merken
  local current_win = vim.api.nvim_get_current_win()
  local current_cursor = vim.api.nvim_win_get_cursor(current_win)

  -- Testbuffer erstellen
  local buf = vim.api.nvim_create_buf(false, true)
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {"Test Window"})

  -- Testfenster erstellen
  local win = vim.api.nvim_open_win(buf, false, {
    relative = "editor",
    width = 30,
    height = 5,
    col = 10,
    row = 5,
    border = "rounded",
    title = "Test Window",
  })

  print("Test window created:", win)

  -- Sofort wieder schließen
  vim.defer_fn(function()
    if vim.api.nvim_win_is_valid(win) then
      local ok, err = pcall(vim.api.nvim_win_close, win, true)
      if ok then
        print("Test window successfully closed")
      else
        print("Failed to close test window:", err)
      end
    else
      print("Test window was already invalid")
    end

    -- Zurück zum ursprünglichen Fenster
    if vim.api.nvim_win_is_valid(current_win) then
      vim.api.nvim_set_current_win(current_win)
      vim.api.nvim_win_set_cursor(current_win, current_cursor)
      print("Returned to original window")
    end

    print("=== Test completed ===")
  end, 500) -- 500ms Verzögerung zum Testen

  return win
end

-- ALLE Floating-Windows schließen (radikale Lösung)
-- Dies schließt ALLE Float-Windows, auch die, die nicht zu diesem Plugin gehören!
function M.close_all_floating()
  vim.cmd([[
    for win in nvim_list_wins()
      let config = nvim_win_get_config(win)
      if config.relative != ''
        call nvim_win_close(win, v:true)
      endif
    endfor
  ]])
end

return M
