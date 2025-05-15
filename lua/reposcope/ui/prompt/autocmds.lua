---@class UIPromptAutocommands
---@field setup_autocmds fun(): nil Autocommands for the UI-Prompt
---@field cleanup_autocmds fun(): nil Cleanup for the UI-Prompt
local M = {}

local prompt_config = require("reposcope.ui.prompt.config")
local ui_state = require("reposcope.state.ui")

--- Autocommands for the UI-Prompt
function M.setup_autocmds()
  pcall(vim.api.nvim_del_augroup_by_name, "reposcope_prompt_autocommands")
  vim.api.nvim_create_augroup("reposcope_prompt_autocommands", { clear = true })

  -- AutoCommand for dynamic prompt update
  vim.api.nvim_create_autocmd("TextChangedI", {
    group = "reposcope_prompt_autocommands",
    pattern = "*",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if ui_state.buffers.prompt and buf == ui_state.buffers.prompt then
        local line_content = vim.api.nvim_buf_get_lines(buf, 1, 2, false)[1] or ""
        line_content = line_content:gsub("[\u{f002}]", ""):gsub("^%s*(.-)%s*$", "%1")
        ui_state.prompt.actual_text = line_content
      end
    end,
  })

  -- AutoCommand for dynamic cursor position during change to insert mode
  vim.api.nvim_create_autocmd("InsertEnter", {
    group = "reposcope_prompt_autocommands",
    pattern = "*",
    callback = function()
      local buf = vim.api.nvim_get_current_buf()
      if ui_state.buffers.prompt and buf == ui_state.buffers.prompt then
        local cursor_pos = prompt_config.prefix_len + #ui_state.prompt.actual_text + 1
        vim.defer_fn(function()
          vim.api.nvim_win_set_cursor(0, { 2, cursor_pos })
        end, 5)
      end
    end,
  })

end

--- Cleans up AutoCommands for the UI-Prompt
function M.cleanup_autocmds()
  pcall(vim.api.nvim_del_augroup_by_name, "reposcope_prompt_autocommands")
end

return M
