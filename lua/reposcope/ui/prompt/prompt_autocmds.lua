---@class UIPromptAutocommands
---@brief Manages autocmds for prompt input buffers (e.g., cursor lock, live input tracking)
---@description
---This module attaches autocmds to the prompt buffers. It ensures the cursor
---stays on line 2 and watches for text changes. Updated input is stored in
---`prompt_state` under the currently focused prompt field
---@field get_active_prompt_field fun(): string|nil Helper to determine which prompt field is currently active
---@field setup_autocmds fun(): nil Autocommands for prompt behavior
---@field cleanup_autocmds fun(): nil Cleans the prompt autocommands
local M = {}

-- State
local ui_state = require("reposcope.state.ui.ui_state")
local prompt_state = require("reposcope.state.ui.prompt_state")


---Helper to determine which prompt field is currently active
---@return string|nil
local function get_active_prompt_field()
  local current_buf = vim.api.nvim_get_current_buf()
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
  pcall(vim.api.nvim_del_augroup_by_name, "reposcope_prompt_autocmds")
  vim.api.nvim_create_augroup("reposcope_prompt_autocmds", { clear = true })

  -- Track Text Input
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = "reposcope_prompt_autocmds",
    pattern = "*",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      local field = get_active_prompt_field()
      if not field then return end

      local lines = vim.api.nvim_buf_get_lines(buf, 1, 2, false)
      local input = (lines[1] or ""):gsub("^%s*(.-)%s*$", "%1")
      prompt_state.set_field_text(field, input)
    end,
  })

  -- Lock cursor to second line  TEST:
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "InsertLeave" }, {
    group = "reposcope_prompt_autocmds",
    pattern = "*",
    callback = function()
      local win = vim.api.nvim_get_current_win()
      local buf = vim.api.nvim_win_get_buf(win)

      if not vim.api.nvim_win_is_valid(win) or not vim.api.nvim_buf_is_valid(buf) then
        return
      end

      -- Check that buffer has at least 2 lines
      local line_count = vim.api.nvim_buf_line_count(buf)
      if line_count < 2 then
        return
      end

      local cursor = vim.api.nvim_win_get_cursor(win)
      if cursor[1] ~= 2 then
        local ok = pcall(vim.api.nvim_win_set_cursor, win, { 2, cursor[2] })
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
  pcall(vim.api.nvim_del_augroup_by_name, "reposcope_prompt_autocmds")
end

return M
