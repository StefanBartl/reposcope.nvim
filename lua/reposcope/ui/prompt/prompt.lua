---@class UIPromptBuffer
---@field init_prompt fun(win: number): nil Initializes the Prompt UI with title and title highlight
local M = {}

local ui_state = require("reposcope.state.ui")
local prompt_config = require("reposcope.ui.prompt.config")

---Initializes Prompt UI with title and highlight
---@param win number Window handle for the prompt
function M.init_prompt(win)
  -- Initialize prompt buf
  local prompt_buf = require("reposcope.utils.protection")
  .create_named_buffer("reposcope://prompt")
  ui_state.buffers.prompt = prompt_buf

  local width = vim.api.nvim_win_get_width(win)
  local title_text = " " .. prompt_config.title .. " "
  local col = math.max(math.floor((width - #title_text) / 2), 0)
  local line_last = ui_state.prompt.actual_text

  -- Set up the prompt lines
  vim.api.nvim_buf_set_lines(prompt_buf, 0, -1, false, {
    string.rep(" ", width), -- Line 0: Virtual text for title
    line_last -- Line 1: Prompt line with saved input
  })

  vim.defer_fn(function()
    if not line_last or line_last == "" then
      vim.api.nvim_win_set_cursor(win, { 2, 1 })
    else
      local pos = vim.fn.strlen(line_last) + 1
      vim.api.nvim_win_set_cursor(win, { 2, pos })
    end
  end, 0)

  -- Background Highlight Namespace
  local ns_bg = vim.api.nvim_create_namespace("reposcope_prompt_bg")
  vim.api.nvim_set_hl(ns_bg, "ReposcopePromptNormal", {
    bg = require("reposcope.ui.config").colortheme.prompt,
    fg = require("reposcope.ui.config").colortheme.foreground,
  })
  vim.api.nvim_win_set_hl_ns(win, ns_bg)

  -- Title Highlight Namespace
  local ns_title = vim.api.nvim_create_namespace("reposcope_prompt_title")
  vim.api.nvim_set_hl(0, "reposcope_prompt_title", {
    bg = require("reposcope.ui.config").colortheme.accent_1,
    fg = require("reposcope.ui.config").colortheme.backg,
    bold = true,
  })

  -- Display title as virtual text in line 0
  vim.api.nvim_buf_set_extmark(prompt_buf, ns_title, 0, col, {
    virt_text = { { title_text, "reposcope_prompt_title" } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

return M
