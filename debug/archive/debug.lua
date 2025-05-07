---@class Debug Debug utilities for inspecting UI-related buffers and windows.
---@field debug_window fun(win: integer): nil Prints detailed information about a specific window.
---@field debug_buffer fun(buf: integer): nil Prints detailed information about a specific buffer.
local M = {}

---Prints detailed information about a specific window.
---@param win integer The window ID to inspect
function M.debug_window(win)
  if not win or not vim.api.nvim_win_is_valid(win) then
    vim.notify("[reposcope][debug] Invalid window handle", vim.log.levels.DEBUG)
    return
  end

  local buf = vim.api.nvim_win_get_buf(win)
  local tab = vim.api.nvim_win_get_tabpage(win)
  local config = vim.api.nvim_win_get_config(win)
  local name = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.bo[buf].buftype
  local filetype = vim.bo[buf].filetype
  local cursor = vim.api.nvim_win_get_cursor(win)
  local position = vim.api.nvim_win_get_position(win)
  local modifiable = vim.api.nvim_buf_get_option(buf, "modifiable")
  local line_count = vim.api.nvim_buf_line_count(buf)

  print("[reposcope][debug][window]")
  print("  Window ID:     " .. win)
  print("  Tabpage ID:    " .. tab)
  print("  Buffer ID:     " .. buf)
  print("  Buffer name:   " .. (name ~= "" and name or "<unnamed>"))
  print("  Buffer type:   " .. buftype)
  print("  Filetype:      " .. filetype)
  print("  Cursor pos:    " .. ("row=%d col=%d"):format(cursor[1], cursor[2]))
  print("  Screen pos:    " .. ("row=%d col=%d"):format(position[1], position[2]))
  print("  Line count:    " .. line_count)
  print("  Modifiable:    " .. tostring(modifiable))
  print("  Window config: " .. vim.inspect(config))
end

---Prints detailed information about a specific buffer.
---@param buf integer The buffer ID to inspect
function M.debug_buffer(buf)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    vim.notify("[reposcope][debug] Invalid buffer handle", vim.log.levels.DEBUG)
    return
  end

  local name = vim.api.nvim_buf_get_name(buf)
  local buftype = vim.api.nvim_buf_get_option(buf, "buftype")
  local filetype = vim.api.nvim_buf_get_option(buf, "filetype")
  local modifiable = vim.api.nvim_buf_get_option(buf, "modifiable")
  local readonly = vim.api.nvim_buf_get_option(buf, "readonly")
  local listed = vim.api.nvim_buf_get_option(buf, "buflisted")
  local loaded = vim.api.nvim_buf_is_loaded(buf)
  local line_count = vim.api.nvim_buf_line_count(buf)

  print("[reposcope][debug][buffer]")
  print("  Buffer ID:     " .. buf)
  print("  Name:          " .. (name ~= "" and name or "<unnamed>"))
  print("  Filetype:      " .. filetype)
  print("  Type:          " .. buftype)
  print("  Modifiable:    " .. tostring(modifiable))
  print("  Readonly:      " .. tostring(readonly))
  print("  Listed:        " .. tostring(listed))
  print("  Loaded:        " .. tostring(loaded))
  print("  Line count:    " .. line_count)
end

return M
