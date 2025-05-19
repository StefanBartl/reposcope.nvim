---@class UIPromptConfig
---@field height integer Height of the prompt window
---@field prefix string Prefix text displayed in the prompt line
---@field prefix_len integer Display width of the prefix
---@field init_prompt_layout fun(buf: number, win: number, title: string): nil Initializes the prompt UI with title, prefix, and complete highlight
local M = {}

-- State Management (Prompt State)
local prompt_state = require("reposcope.state.ui.prompt_state")


M.height = 3
local w_prefix = false
M.prefix = " " .. "\u{f002}" .. " "
M.prefix_len = vim.fn.strdisplaywidth(M.prefix)
M.pos = 1

--NOTE: Should be in layout not in config

---Initializes Prompt UI with title, prefix, and full highlight
---@param buf number Buffer handle for the prompt
---@param win number Window handle for the prompt
---@param title string Title text to display in the prompt
function M.init_prompt_layout(buf, win, title)
  local title_text = " " .. title .. " "

  local width = vim.api.nvim_win_get_width(win)
  local col = math.max(math.floor((width - #title_text) / 2), 0)
  local line_last = prompt_state.get_prompt_text()

  -- Set up the prompt lines

  if w_prefix == true then

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      string.rep(" ", width), -- Line 0: Virtual text for title
      M.prefix .. line_last -- Line 1: Prompt line with prefix and saved input
    })

    vim.defer_fn(function()
      if not line_last or line_last == "" then
        M.pos = M.prefix_len
        vim.api.nvim_win_set_cursor(win, { 2, M.pos })
      else
        M.pos = M.prefix_len + vim.fn.strlen(line_last) + 2
        vim.api.nvim_win_set_cursor(win, { 2, M.pos })
      end
    end, 0)
  end

  if w_prefix == false then
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
      string.rep(" ", width), -- Line 0: Virtual text for title
      line_last -- Line 1: Prompt line with saved input
    })

    vim.defer_fn(function()
      if not line_last or line_last == "" then
        vim.api.nvim_win_set_cursor(win, { 2, M.pos })
      else
        M.pos = vim.fn.strlen(line_last) + 1
        vim.api.nvim_win_set_cursor(win, { 2, M.pos })
      end
    end, 0)

  end


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
  vim.api.nvim_buf_set_extmark(buf, ns_title, 0, col, {
    virt_text = { { title_text, "reposcope_prompt_title" } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

return M
