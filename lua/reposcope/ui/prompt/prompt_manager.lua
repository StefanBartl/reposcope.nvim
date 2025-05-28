---@class UIPromptManager
---@brief Manages the creation and orchestration of prompt windows
---@description
---This module initializes all required buffers, builds a layout plan based on
---`prompt_config.fields`, and then creates the corresponding windows dynamically.
---Window handles are stored in `ui_state.windows.prompt`, indexed by field name.
---@field open_windows fun(): nil Initializes and renders the prompt UI
---@field close_windows fun(): nil Closes all prompt-related windows  --NOTE:  niuy
local M = {}

---@description Forward declaration for private functions
local add_title_to_prompt_buffer, load_state_into_prompt, set_prompt_start_idx

-- System
local api = vim.api
-- Config & Utilities
local prompt_config = require("reposcope.ui.prompt.prompt_config")
local notify = require("reposcope.utils.debug").notify
-- State
local ui_state = require("reposcope.state.ui.ui_state")
local prompt_state = require("reposcope.state.ui.prompt_state")
-- Prompt Components
local prompt_buffers = require("reposcope.ui.prompt.prompt_buffers")
local prompt_layout = require("reposcope.ui.prompt.prompt_layout")
local focus_first_input = require("reposcope.ui.prompt.prompt_focus").focus_first_input
local navigate = require("reposcope.ui.prompt.prompt_focus")

---Opens the prompt UI based on active fields and layout configuration
---@return nil
function M.open_windows()
  prompt_buffers.setup_buffers()

  local layout = prompt_layout.build_layout()
  if not layout or #layout == 0 then
    notify("[reposcope] Layout empty or invalid", 4)
    return
  end

  ui_state.windows.prompt = {}

  -- Initialize all prompt buffers and windows
  for _, section in ipairs(layout) do
    local buf = section.buffer
    local width = section.width
    local field = section.name
    local col = section.col

    if not buf or not api.nvim_buf_is_valid(buf) then
      notify("[reposcope] Invalid buffer for field: " .. tostring(field), 2)
      goto continue
    end

    local focusable = field ~= "prefix"

    local ok, win = pcall(api.nvim_open_win, buf, true, {
      relative = "editor",
      row = prompt_config.row,
      col = col,
      width = width,
      height = prompt_config.height,
      style = "minimal",
      border = "none",
      focusable = focusable,
    })

    if not ok or not api.nvim_win_is_valid(win) then
      notify("[reposcope] Failed to open window for field: " .. tostring(field), 4)
      goto continue
    end

    ui_state.windows.prompt[field] = win

    if field ~= "prefix" then
      local success, err = pcall(add_title_to_prompt_buffer, buf, string.upper(" " .. field .. " "), section.width)
      if not success then
        notify("[reposcope] Failed to add title to " .. field .. ": " .. tostring(err), 2)
      end
    end

    ::continue::
  end

  load_state_into_prompt()
  set_prompt_start_idx()
  focus_first_input()
end


---Closes all prompt-related windows safely
---@return nil
function M.close_windows()
  if not ui_state.windows.prompt then return end

  for field, win in pairs(ui_state.windows.prompt) do
    if win and api.nvim_win_is_valid(win) then
      pcall(api.nvim_win_close, win, true)
    end
    ui_state.windows.prompt[field] = nil
  end
end


 ---@private
---@brief Adds a centered virtual title to a prompt buffer
---@param buf integer Buffer handle
---@param field string Prompt field name (e.g. "keywords", "owner")
---@param width integer Width of the window the buffer will be displayed in
function add_title_to_prompt_buffer(buf, field, width)
  local ns = api.nvim_create_namespace("reposcope_prompt_title")

  -- Make sure line 0 exists
  local line0 = api.nvim_buf_get_lines(buf, 0, 1, false)[1]
  if not line0 then
    api.nvim_buf_set_lines(buf, 0, 1, false, { " " })
  end

  local fields = prompt_config.get_fields()
  local title = fields[field] or string.upper(" " .. field .. " ")

  local win_col = math.floor((width - #title) / 2)

  api.nvim_set_hl(0, "ReposcopePromptTitle", {
    bg = require("reposcope.ui.config").colortheme.accent_1,
    fg = require("reposcope.ui.config").colortheme.backg,
    bold = true,
  })

  api.nvim_buf_set_extmark(buf, ns, 0, 0, {
    virt_text = { { title, "ReposcopePromptTitle" } },
    virt_text_win_col = win_col,
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end


---Loads prompt field values from prompt_state and injects them into the corresponding buffers
---@private
---@return nil
function load_state_into_prompt()
  local fields = prompt_config.get_fields()

  for _, field in ipairs(fields) do
    local buf = ui_state.buffers.prompt[field]
    if buf and vim.api.nvim_buf_is_valid(buf) then
      local text = prompt_state.get_field_text(field)
      if type(text) == "string" and text ~= "" then
        vim.api.nvim_buf_set_lines(buf, 1, 2, false, { text })
      end
    end
  end

end

---Set the field starting index for prompt
---@private
---@return nil
function set_prompt_start_idx()
  local fields = prompt_config.get_fields()

  for i, field in ipairs(fields) do
    local win = ui_state.windows.prompt and ui_state.windows.prompt[field]
    if win and vim.api.nvim_win_is_valid(win) then
      local cfg = vim.api.nvim_win_get_config(win)
      if cfg.focusable then
        navigate.set_current_index(i)
        break
      end
    end
  end
end

return M
