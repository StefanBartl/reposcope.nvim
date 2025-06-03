---@module 'reposcope.ui.prompt.prompt_autocmds'
---@brief Manages autocmds for prompt input buffers (e.g., cursor lock, live input tracking)
---@description
---This module attaches autocmds to the prompt buffers. It ensures the cursor
---stays on line 2 and watches for text changes. Updated input is stored in
---`prompt_state` under the currently focused prompt field

---@class UIPromptAutocommands : UIPromptAutocommandsModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_win_get_cursor = api.nvim_win_get_cursor
local nvim_buf_get_lines = api.nvim_buf_get_lines
local nvim_win_set_cursor = api.nvim_win_set_cursor
local nvim_get_current_buf = api.nvim_get_current_buf
local nvim_del_augroup_by_name = api.nvim_del_augroup_by_name
local nvim_create_augroup = api.nvim_create_augroup
local nvim_create_autocmd = api.nvim_create_autocmd
local nvim_get_current_win = api.nvim_get_current_win
local nvim_win_get_buf = api.nvim_win_get_buf
local nvim_buf_line_count = api.nvim_buf_line_count
-- State
local ui_state = require("reposcope.state.ui.ui_state")
local prompt_set_field_text = require("reposcope.state.ui.prompt_state").set_field_text


---Helper to determine which prompt field is currently active
---@return string|nil
local function get_active_prompt_field()
  local current_buf = nvim_get_current_buf()
  for field, buf in pairs(ui_state.buffers.prompt or {}) do
    if buf == current_buf then
      return field
    end
  end
  return nil
end


---Autocommands for prompt behavior
---@return nil
function M.setup_autocmds()
  pcall(nvim_del_augroup_by_name, "reposcope_prompt_autocmds")
  nvim_create_augroup("reposcope_prompt_autocmds", { clear = true })

  -- Track Text Input
  nvim_create_autocmd("TextChangedI", {
    group = "reposcope_prompt_autocmds",
    pattern = "*",
    callback = function()
      local buf = nvim_get_current_buf()
      local field = get_active_prompt_field()
      if not field then return end

      local lines = nvim_buf_get_lines(buf, 1, 2, false)
      local input = (lines[1] or ""):gsub("^%s*(.-)%s*$", "%1")
      prompt_set_field_text(field, input)
    end,
  })

  -- Lock cursor to second line
  nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "InsertLeave" }, {
    group = "reposcope_prompt_autocmds",
    pattern = "*",
    callback = function()
      local win = nvim_get_current_win()
      local buf = nvim_win_get_buf(win)

      if not nvim_win_is_valid(win) or not nvim_buf_is_valid(buf) then
        return
      end

      -- Check that buffer has at least 2 lines
      local line_count = nvim_buf_line_count(buf)
      if line_count < 2 then
        return
      end

      local cursor = nvim_win_get_cursor(win)
      if cursor[1] ~= 2 then
        local ok = pcall(nvim_win_set_cursor, win, { 2, cursor[2] })
        if not ok then
          require("reposcope.utils.debug").notify("[prompt] Skipped cursor reset (window state invalid)", 2)
        end
      end
    end,
  })
end

---Cleans the prompt autocommands
---@return nil
function M.cleanup_autocmds()
  pcall(nvim_del_augroup_by_name, "reposcope_prompt_autocmds")
end

return M
