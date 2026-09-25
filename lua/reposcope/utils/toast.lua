---@module 'reposcope.utils.toast'
---@brief In-plugin notifications: a corner popup plus a yankable history.
---@description
--- Reposcope's messages used to go through `vim.notify`, which on a plain
--- Neovim UI is `nvim_echo` -- long or multi-line text (a failed `git push`,
--- say) then pops up as a `:messages` / more-prompt and steals focus. This
--- module keeps them inside the plugin instead:
---
---   * every message is appended to an in-memory history (`M.history()`),
---     shown in a scratch buffer by `:Reposcope messages`, so its text can be
---     yanked later without going through the message area
---   * a non-focus-stealing `ui.kit` toast in the top-right corner shows it,
---     wrapped to the toast width and colored by level
---   * only when the toast cannot be shown (no `ui.nvim`, no UI) it falls back
---     to `vim.notify`, so a message is never lost

---@class Reposcope.Utils.Toast
local M = {}

local WIDTH = 38 -- ui.kit toasts are 40 columns wide, minus the border
local MAX_LINES = 12
local HISTORY_MAX = 200

-- Per level: title, toast highlight group, milliseconds on screen.
local LEVELS = {
  [vim.log.levels.TRACE] = { name = "trace", hl = "Comment", timeout = 3000 },
  [vim.log.levels.DEBUG] = { name = "debug", hl = "Comment", timeout = 3000 },
  [vim.log.levels.INFO] = { name = "info", hl = "DiagnosticInfo", timeout = 4000 },
  [vim.log.levels.WARN] = { name = "warn", hl = "DiagnosticWarn", timeout = 6000 },
  [vim.log.levels.ERROR] = { name = "error", hl = "DiagnosticError", timeout = 10000 },
}

---@class Reposcope.Utils.Toast.Entry
---@field time string
---@field level integer
---@field message string

---@type Reposcope.Utils.Toast.Entry[]
local history = {}

---Hard-wraps `text` to `width` display columns and caps the line count.
---@param text string
---@param width integer
---@param max_lines integer
---@return string[]
local function wrap(text, width, max_lines)
  local out = {}
  for _, raw in ipairs(vim.split(text, "\n", { plain = true })) do
    local line = raw:gsub("\t", "  "):gsub("%s+$", "")
    if line == "" then
      out[#out + 1] = ""
    else
      while vim.fn.strdisplaywidth(line) > width do
        -- Prefer a break at the last space inside the window.
        local cut = width
        local head = vim.fn.strcharpart(line, 0, width)
        local space = head:match("^.*() ")
        if space and space > width / 3 then cut = space - 1 end
        out[#out + 1] = vim.fn.strcharpart(line, 0, cut)
        line = vim.fn.strcharpart(line, cut):gsub("^%s+", "")
      end
      out[#out + 1] = line
    end
  end
  if #out > max_lines then
    out = vim.list_slice(out, 1, max_lines)
    out[max_lines] = "... (full text: :Reposcope messages)"
  end
  return out
end

---Shows `message` as a corner toast.
---@param message string
---@param level integer
---@return boolean shown
local function show_toast(message, level)
  local ok_toast, toast = pcall(require, "ui.kit.toast")
  if not ok_toast then return false end

  local spec = LEVELS[level] or LEVELS[vim.log.levels.INFO]
  local ok = pcall(toast.open, {
    title = "reposcope " .. spec.name,
    message = wrap(message, WIDTH, MAX_LINES),
    timeout = spec.timeout,
    theme = { hl = { border = spec.hl, title = spec.hl } },
  })
  return ok
end

---Records `message` in the history and shows it as a toast.
---@param message string
---@param level? integer vim.log.levels value (default: INFO)
---@return nil
function M.notify(message, level)
  level = level or vim.log.levels.INFO
  message = tostring(message)

  history[#history + 1] = { time = os.date("%H:%M:%S"), level = level, message = message }
  if #history > HISTORY_MAX then table.remove(history, 1) end

  if not show_toast(message, level) then vim.notify(message, level) end
end

---The recorded messages, oldest first.
---@return Reposcope.Utils.Toast.Entry[]
function M.history() return history end

---Forgets every recorded message.
---@return nil
function M.clear() history = {} end

---Opens the history in a scratch buffer (newest last) so it can be yanked.
---@return integer|nil bufnr
function M.show_history()
  local lines = {}
  for _, entry in ipairs(history) do
    local spec = LEVELS[entry.level] or LEVELS[vim.log.levels.INFO]
    local prefix = ("%s %-5s "):format(entry.time, spec.name:upper())
    local pad = (" "):rep(#prefix)
    for i, text in ipairs(vim.split(entry.message, "\n", { plain = true })) do
      lines[#lines + 1] = (i == 1 and prefix or pad) .. text
    end
  end
  if #lines == 0 then lines = { "(no reposcope messages yet)" } end

  vim.cmd("botright new")
  local buf = vim.api.nvim_get_current_buf()
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].buftype = "nofile"
  vim.bo[buf].bufhidden = "wipe"
  vim.bo[buf].swapfile = false
  vim.bo[buf].modifiable = false
  vim.api.nvim_buf_set_name(buf, "reposcope://messages")
  vim.cmd("normal! G")
  vim.keymap.set("n", "q", "<Cmd>close<CR>", { buffer = buf, silent = true, desc = "Close reposcope messages" })
  return buf
end

return M
