---@module 'reposcope.ui.actions.help_view'
---@brief `?` keybinding cheatsheet — a floating window listing Reposcope's active keymaps.
---@description
--- Built from the same tables that back `docs/BINDINGS.md` and the which-key
--- `desc` fields (`bindings.keymaps.list_active_prompt_keymaps()` and
--- `config.keymaps`), so there is exactly one source of truth for "what keys
--- are currently live" instead of a hand-maintained duplicate list that would
--- drift the moment a keymap is rebound or disabled via `setup()`.

---@class ActionHelpView : ActionHelpViewModule
local M = {}

local kit = require("lib.nvim.ui.kit")

---@type Lib.UI.Kit.Surface|nil
local _surf

---@return nil
local function close() if _surf then _surf:close() end end

---Builds the display lines: global open/close, active prompt keymaps
--- (grouped by action, multiple lhs joined with ", "), and the close-UI keys.
---@return string[]
local function build_lines()
  local keymaps = require("reposcope.bindings.keymaps")
  local cfg_get_option = require("reposcope.config").get_option

  local lines = { "" }

  lines[#lines + 1] = " Global"
  local map_cfg = cfg_get_option("keymaps") or {}
  if map_cfg.open and map_cfg.open ~= "" then
    lines[#lines + 1] = ("  %-16s  %s"):format(map_cfg.open, "Open Reposcope")
  end
  if map_cfg.close and map_cfg.close ~= "" then
    lines[#lines + 1] = ("  %-16s  %s"):format(map_cfg.close, "Close Reposcope")
  end
  lines[#lines + 1] = ""

  lines[#lines + 1] = " Prompt"
  local rows = keymaps.list_active_prompt_keymaps()
  local widest = 0
  for _, row in ipairs(rows) do
    widest = math.max(widest, #table.concat(row.lhs, ", "))
  end
  for _, row in ipairs(rows) do
    local lhs = table.concat(row.lhs, ", ")
    lines[#lines + 1] = ("  %-" .. widest .. "s  %s"):format(lhs, row.desc)
  end
  lines[#lines + 1] = ""

  lines[#lines + 1] = " Close UI"
  lines[#lines + 1] = "  <Esc>, <C-w>       Close Reposcope"
  lines[#lines + 1] = ""

  lines[#lines + 1] = " q / <Esc>  close this help"
  return lines
end

---Shows the keymap cheatsheet, or closes it if already open (toggle).
---@return nil
function M.show()
  if _surf and _surf:is_valid() then
    close()
    return
  end

  local lines = build_lines()
  local max_w = math.floor(vim.o.columns * 0.9)
  local max_h = math.floor(vim.o.lines * 0.8)
  local content_w = 20
  for _, l in ipairs(lines) do content_w = math.max(content_w, vim.fn.strdisplaywidth(l)) end

  _surf = kit.viewer({
    lines = lines,
    title = "Reposcope Keymaps",
    filetype = "reposcope-help",
    width = math.min(content_w + 2, max_w),
    height = math.min(#lines, max_h),
  })
  if not _surf then return end
  _surf:on_close(function() _surf = nil end)
end

---Closes the cheatsheet if open.
---@return nil
function M.close() close() end

return M
