---@class UIPromptAutocommands
---@field setup_autocmds fun(): nil Autocommands for the UI-Prompt
---@field cleanup_autocmds fun(): nil Cleanup for the UI-Prompt
local M = {}

-- State Management (UI State, Prompt State)
local ui_state = require("reposcope.state.ui.ui_state")
local prompt_state = require("reposcope.state.ui.prompt_state")


--- Autocommands for the UI-Prompt
function M.setup_autocmds()
  pcall(vim.api.nvim_del_augroup_by_name, "reposcope_prompt_autocommands")
  vim.api.nvim_create_augroup("reposcope_prompt_autocommands", { clear = true })

  -- AutoCommand for dynamic prompt update. Sets sanitized text
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = "reposcope_prompt_autocommands",
    pattern = "*",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if ui_state.buffers.prompt and buf == ui_state.buffers.prompt then
        local line_content = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] or ""
        line_content = line_content:gsub("[\u{f002}]", ""):gsub("^%s*(.-)%s*$", "%1") -- remove prompt prefix
        prompt_state.set_prompt_text(line_content)
      end
    end,
  })

  -- AutoCommand to ensure cursor stays in the second line
  vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI", "InsertEnter", "InsertLeave" }, {
    group = "reposcope_prompt_autocommands",
    pattern = "*",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if ui_state.buffers.prompt and buf == ui_state.buffers.prompt then
        local cursor_pos = vim.api.nvim_win_get_cursor(ui_state.windows.prompt)
        if cursor_pos[1] ~= 2 then
          -- Prevent moving the cursor out of line 2
          vim.api.nvim_win_set_cursor(ui_state.windows.prompt, { 2, cursor_pos[2] })
        end
      end
    end,
  })
end

--- Cleans up AutoCommands for the UI-Prompt
function M.cleanup_autocmds()
  pcall(vim.api.nvim_del_augroup_by_name, "reposcope_prompt_autocommands")
end

return M
