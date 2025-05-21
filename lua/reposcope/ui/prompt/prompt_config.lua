---@class UIPromptConfig
---@brief Static configuration values for the prompt input layout
---@description
---This module defines the core configuration used to render the prompt input,
---including the active input fields, visual prefix, prompt height, and layout
---constants. It provides no side effects and exports only static values.
---@field fields string[] Active prompt fields (e.g. keywords, author)
---@field prefix string Icon/prefix displayed left of user input
---@field prefix_len integer Display width of prefix (used for window sizing)
---@field height integer Height of the prompt input window in lines

local M = {}

-- UI Config
local ui_config = require("reposcope.ui.config")


M.fields = { "prefix", "keywords" }
M.row = ui_config.row
M.col = ui_config.col
M.width = ui_config.width / 2
M.height = 3
-- Prefix
M.prefix = " " .. "\u{f002}" .. " "
M.prefix_len = vim.fn.strdisplaywidth(M.prefix)
M.prefix_win_width = M.prefix_len + 2

return M
