---@class UIPromptBuffers
---@brief Initializes and registers all prompt input buffers.
---@description
--- This module prepares buffer handles for all possible prompt fields (prefix, keywords, author, etc.)
--- and stores them in `ui_state.buffers` under their respective keys. Buffers are created safely
--- using pcall and can later be dynamically attached to windows depending on the selected layout.
---@field setup_buffers fun(): nil Creates and registers all supported prompt buffers into ui_state
local M = {}

-- Prompt config
local prompt_config = require("reposcope.ui.prompt.prompt_config")
-- Utilities
local notify = require("reposcope.utils.debug").notify
local create_buf = require("reposcope.utils.protection").create_named_buffer
-- State
local ui_state = require("reposcope.state.ui.ui_state")


local FIELDS = prompt_config.get_available_fields()

---Creates and registers all supported prompt buffers into ui_state
---@return nil
function M.setup_buffers()
  ui_state.buffers.prompt = ui_state.buffers.prompt or {}

  for _, field in ipairs(FIELDS) do
    local name = "reposcope://prompt_" .. field
    local ok, buf = pcall(create_buf, name)
    if not ok or not buf or not vim.api.nvim_buf_is_valid(buf) then
      notify("[prompt_buffers] Failed to create buffer for field: " .. field, 4)

    else
        vim.api.nvim_buf_set_option(buf, "buftype", "nofile")
        vim.api.nvim_buf_set_option(buf, "bufhidden", "hide")
        vim.api.nvim_buf_set_option(buf, "swapfile", false)
        vim.api.nvim_buf_set_option(buf, "modifiable", true)

        if field == "prefix" then
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            " ",
            prompt_config.prefix
          })
          vim.api.nvim_buf_set_option(buf, "modifiable", false)
          vim.api.nvim_buf_set_option(buf, "readonly", true)
        else
          vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
            " ",
            ""
          })
        end

        ui_state.buffers.prompt[field] = buf
      end
  end
end

return M
