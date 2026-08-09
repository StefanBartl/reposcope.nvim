---@module 'reposcope.ui.actions.favorites_view'
---@brief Lists favorited repositories in a scrollable floating window.
---@description
--- Read-only overview for `:Reposcope favorites [list]` — one entry per
--- favorite (owner/name, description, stars, URL). Management (add/remove)
--- happens via the `toggle_favorite` prompt keymap while browsing, not here.

---@class ActionFavoritesView : ActionFavoritesViewModule
local M = {}

local kit = require("lib.nvim.ui.kit")

---@return string[]
local function build_lines()
  local favorites = require("reposcope.state.favorites_state").list()

  if #favorites == 0 then
    return {
      "",
      " No favorites yet.",
      "",
      " Toggle one with the 'toggle_favorite' prompt keymap (default <C-f>).",
      "",
    }
  end

  local lines = { "" }
  for _, f in ipairs(favorites) do
    lines[#lines + 1] = ("  %s/%s"):format(f.owner, f.name)
    lines[#lines + 1] = ("    %s"):format(f.description ~= "" and f.description or "No description")
    if f.stargazers_count then
      lines[#lines + 1] = ("    \u{2605} %d   %s"):format(f.stargazers_count, f.html_url or "")
    elseif f.html_url then
      lines[#lines + 1] = ("    %s"):format(f.html_url)
    end
    lines[#lines + 1] = ""
  end
  lines[#lines + 1] = " q / <Esc>  close"

  return lines
end

---Shows the favorites overview.
---@return nil
function M.show()
  local lines = build_lines()
  local max_w = math.floor(vim.o.columns * 0.9)
  local max_h = math.floor(vim.o.lines * 0.8)
  local content_w = 20
  for _, l in ipairs(lines) do content_w = math.max(content_w, vim.fn.strdisplaywidth(l)) end

  kit.viewer({
    lines = lines,
    title = "Reposcope Favorites",
    filetype = "reposcope-favorites",
    width = math.min(content_w + 2, max_w),
    height = math.min(#lines, max_h),
  })
end

return M
