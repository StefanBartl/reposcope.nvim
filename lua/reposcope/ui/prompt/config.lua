--- @class UIPromptConfig
local M = {}

M.height = 3
M.prefix = " " .. "\u{f002}" .. "   "
M.prefix_len = vim.fn.strdisplaywidth(M.prefix)

--NOTE: Should bei in layout not in config

--- Initialisiert Prompt UI mit Titel, Prefix und vollständigem Highlight
---@param buf number
---@param win number
---@param title string
function M.init_prompt_layout(buf, win, title)
  local title_text = " " .. title .. " "

  local width = vim.api.nvim_win_get_width(win)
  local col = math.max(math.floor((width - #title_text) / 2), 0)

  vim.api.nvim_buf_set_lines(buf, 0, -1, false, {
    string.rep(" ", width),         -- Zeile 0: virt_text für Titel
    M.prefix      -- Zeile 1: Prompt-Zeile mit Prefix
  })

  vim.api.nvim_win_set_cursor(win, { 2, M.prefix_len })

  local ns_bg = vim.api.nvim_create_namespace("reposcope_prompt_bg")
  vim.api.nvim_set_hl(ns_bg, "ReposcopePromptNormal", {
    bg = require("reposcope.ui.config").colortheme.prompt,
    fg = require("reposcope.ui.config").colortheme.foreground,
  })
  vim.api.nvim_win_set_hl_ns(win, ns_bg)

  local ns_title = vim.api.nvim_create_namespace("reposcope_prompt_title")
  vim.api.nvim_set_hl(0, "reposcope_prompt_title", {
    bg = require("reposcope.ui.config").colortheme.accent_1,
    fg = require("reposcope.ui.config").colortheme.backg,
    bold = true,
  })

  -- Titel in Zeile 0 als virt_text anzeigen
  vim.api.nvim_buf_set_extmark(buf, ns_title, 0, col, {
    virt_text = { { title_text, "reposcope_prompt_title" } },
    virt_text_pos = "overlay",
    hl_mode = "combine",
  })
end

return M
