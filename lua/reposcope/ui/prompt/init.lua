---@desc Forward declarations
local default

---@class UIPrompt Opens and initializes the prompt input window in the Reposcope UI.
---@field open_prompt fun(): nil Opens the user input prompt window in the Reposcope UI
---@field default fun(): nil Default layout for the prompt
local M = {}

local config = require("reposcope.config")
local ui_config = require("reposcope.ui.config")
local prompt_config = require("reposcope.ui.prompt.config")
local prompt_autocmds = require("reposcope.ui.prompt.autocmds")
local ui_state = require("reposcope.state.ui")
local protect_prompt = require("reposcope.ui.prompt.protect_prompt_input")
local debug = require("reposcope.utils.debug")

---Opens the user input prompt window in the Reposcope UI
function M.open_prompt()

  local prompt_buf = require("reposcope.utils.protection")
      .create_named_buffer("reposcope://prompt")
  ui_state.buffers.prompt = prompt_buf

  local prefix_buf = require("reposcope.utils.protection")
      .create_named_buffer("reposcope://prompt_prefix")

  ui_state.buffers.prompt_prefix = prefix_buf
  M.init_prompt_prefix_buf()

  if config.options.layout == "default" then
    default()
  else
    debug.notify("Unsupported layout: " .. config.options.layout, 4)
  end

  prompt_config.init_prompt_layout(ui_state.buffers.prompt, ui_state.windows.prompt, " prompt ")
  protect_prompt.protect(prompt_buf)
  prompt_autocmds.setup_autocmds()

  vim.schedule(function()
    vim.cmd("startinsert")
  end)
end

function default()
  -- Prefix window
  ui_state.windows.prompt_prefix = vim.api.nvim_open_win(ui_state.buffers.prompt_prefix, true, {
    relative = "editor",
    row = ui_config.row,
    col = ui_config.col,
    width = prompt_config.prefix_len + 2,
    height = prompt_config.height,
    style = "minimal"
  })

  -- Prompt window
  ui_state.windows.prompt = vim.api.nvim_open_win(ui_state.buffers.prompt, true, {
    relative = "editor",
    row = ui_config.row,
    col = ui_config.col + prompt_config.prefix_len + 2,
    width = (ui_config.width / 2) - prompt_config.prefix_len - 2,
    height = prompt_config.height,
    style = "minimal"
  })
end

---Initalize buffer for the prefix prompt window
function M.init_prompt_prefix_buf()
  if not vim.api.nvim_buf_is_valid(ui_state.buffers.prompt_prefix) then
    debug.notify("[ERROR] Prefix Buffer is not valid", 4)
    return
  end

  local prefix = " " .. "\u{f002}" .. " "

  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "buftype", "nofile")
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "bufhidden", "hide")
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "modifiable", true)
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "swapfile", false)

  vim.api.nvim_buf_set_lines(ui_state.buffers.prompt_prefix, 0, -1, false, {
    "",
    prefix })
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "modifiable", false)
  vim.api.nvim_buf_set_option(ui_state.buffers.prompt_prefix, "readonly", true)
end

return M
