---@module 'reposcope.ui.prompt.prompt_manager'
---@brief Manages the creation and orchestration of prompt windows
---@description
---This module initializes all required buffers, builds a layout plan based on
---`prompt_config.fields`, and then creates the corresponding windows dynamically.

---@class UIPromptManager : UIPromptManagerModule
local M = {}

-- Vim Utilities
local api = vim.api
local nvim_buf_is_valid = api.nvim_buf_is_valid
local nvim_buf_set_lines = api.nvim_buf_set_lines
local nvim_buf_get_lines = api.nvim_buf_get_lines
local nvim_buf_set_extmark = api.nvim_buf_set_extmark
local nvim_win_is_valid = api.nvim_win_is_valid
local nvim_win_close = api.nvim_win_close
local nvim_open_win = api.nvim_open_win
local nvim_set_hl = api.nvim_set_hl
local nvim_create_namespace = api.nvim_create_namespace
-- Config & Utilities
local prompt_config = require("reposcope.ui.prompt.prompt_config")
local get_fields = require("reposcope.ui.prompt.prompt_config").get_fields
local notify = require("reposcope.utils.debug").notify
-- State
local ui_state = require("reposcope.state.ui.ui_state")
local get_field_text = require("reposcope.state.ui.prompt_state").get_field_text
-- Prompt Components
local setup_buffers = require("reposcope.ui.prompt.prompt_buffers").setup_buffers
local prompt_build_layout = require("reposcope.ui.prompt.prompt_layout").build_layout
local focus_first_input = require("reposcope.ui.prompt.prompt_focus").focus_first_input


---@private
---Adds a centered virtual title to a prompt buffer
---@param buf integer Buffer handle
---@param field string Prompt field name (e.g. "keywords", "owner")
---@param width integer Width of the window the buffer will be displayed in
local function _add_title_to_prompt_buffer(buf, field, width)
  local ns = nvim_create_namespace("reposcope_prompt_title")

  -- Make sure line 0 exists
  local line0 = nvim_buf_get_lines(buf, 0, 1, false)[1]
  if not line0 then
    nvim_buf_set_lines(buf, 0, 1, false, { " " })
  end

  local fields = get_fields()
  local title = fields[field] or string.upper(" " .. field .. " ")

  local win_col = math.floor((width - #title) / 2)

  nvim_set_hl(0, "ReposcopePromptTitle", {
    bg = require("reposcope.ui.config").colortheme.accent_1,
    fg = require("reposcope.ui.config").colortheme.backg,
    bold = true,
  })

  nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = { { title, "ReposcopePromptTitle" } },
    virt_text_win_col = win_col,
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end


---@private
---Injects prompt_state values into associated buffers
---@return nil
local function _load_state_into_prompt()
  local fields = get_fields()
  local buffers = ui_state.buffers.prompt or {}
  local get = get_field_text

  for i = 1, #fields do
    local field = fields[i]
    local buf = buffers[field]

    if type(buf) == "number" and nvim_buf_is_valid(buf) then
      local text = get(field)
      if type(text) == "string" and text ~= "" then
        nvim_buf_set_lines(buf, 1, 2, false, { text })
      end
    end
  end
end


---Opens the prompt UI based on active fields and layout configuration
---@return nil
function M.open_windows()
  setup_buffers()

  local layout = prompt_build_layout()
  if type(layout) ~= "table" or #layout == 0 then
    notify("[reposcope] Layout empty or invalid", 4)
    return
  end

  ui_state.windows.prompt = {}

  local cfg = prompt_config
  local win_store = ui_state.windows.prompt
  local open_win = nvim_open_win
  local buf_valid = nvim_buf_is_valid
  local win_valid = nvim_win_is_valid

  for i = 1, #layout do
    local section = layout[i]
    local field = section.name
    local buf = section.buffer
    local col = section.col
    local width = math.floor(section.width)

    if type(buf) ~= "number" or not buf_valid(buf) then
      notify("[reposcope] Invalid buffer for field: " .. tostring(field), 2)
      goto continue
    end

    local focusable = (field ~= "prefix")

    local ok, win = pcall(open_win, buf, true, {
      relative = "editor",
      row = cfg.row,
      col = col,
      width = width,
      height = cfg.height,
      style = "minimal",
      border = "none",
      focusable = focusable,
    })

    if not ok or not win_valid(win) then
      notify("[reposcope] Failed to open window for field: " .. tostring(field), 4)
      goto continue
    end

    win_store[field] = win

    if focusable then
      local ok_title, err = pcall(_add_title_to_prompt_buffer, buf, field, width)
      if not ok_title then
        notify("[reposcope] Failed to add title to " .. field .. ": " .. tostring(err), 2)
      end
    end

    ::continue::
  end

  _load_state_into_prompt()
  focus_first_input()
end

---Closes all prompt-related windows safely
---@return nil
function M.close_windows()
  if not ui_state.windows.prompt then return end

  for field, win in pairs(ui_state.windows.prompt) do
    if win and nvim_win_is_valid(win) then
      pcall(nvim_win_close, win, true)
    end
    ui_state.windows.prompt[field] = nil
  end
end

return M
