---@module 'reposcope.ui.prompt.prompt_bffers'
---@brief Initializes and registers all prompt input buffers.
---@description
--- This module prepares buffer handles for all possible prompt fields (prefix, keywords, owner, etc.)
--- and stores them in `ui_state.buffers` under their respective keys. Buffers are created safely
--- using pcall and can later be dynamically attached to windows depending on the selected layout.

---@class UIPromptBuffers : UIPromptBuffersModule
local M = {}

-- Vim Utilities
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_buf_set_lines = vim.api.nvim_buf_set_lines
-- Prompt config
local prompt_config = require("reposcope.ui.prompt.prompt_config")
local get_available_fields = require("reposcope.ui.prompt.prompt_config").get_available_fields
-- State
local ui_state = require("reposcope.state.ui.ui_state")
-- Utilities
local notify = require("reposcope.utils.debug").notify
local create_named_buf = require("reposcope.utils.protection").create_named_buffer


local FIELDS = get_available_fields()

---Creates and registers all supported prompt buffers into ui_state
---@return nil
function M.setup_buffers()
  ui_state.buffers.prompt = ui_state.buffers.prompt or {}

  local buf_create = create_named_buf
  local config = prompt_config
  local set_lines = nvim_buf_set_lines
  local buffers = ui_state.buffers.prompt

  for i = 1, #FIELDS do
    local field = FIELDS[i]
    local name = "reposcope://prompt_" .. field

    local ok, buf = pcall(buf_create, name)
    if not ok or not buf or not nvim_buf_is_valid(buf) then
      notify("[prompt_buffers] Failed to create buffer for field: " .. field, 4)
    else
      vim.bo[buf].buftype = "nofile"
      vim.bo[buf].bufhidden = "hide"
      vim.bo[buf].swapfile = false
      vim.bo[buf].modifiable = true

      -- Set initial content based on field type
      if field == "prefix" then
        set_lines(buf, 0, -1, false, { " ", config.prefix })
        vim.bo[buf].modifiable = false
        vim.bo[buf].readonly = true
      else
        set_lines(buf, 0, -1, false, { " ", "" })
      end

      buffers[field] = buf
    end
  end
end

return M
