---@module 'reposcope.ui.actions.status_view'
---@brief Renders `:Reposcope status` results and displays them in the user's chosen output.
---@description
--- `vim.notify` truncates and can't be scrolled, which makes it a poor fit for
--- a repository-status overview that can easily run to dozens of lines. This
--- module renders the aligned status table once and then hands it to one of
--- several output backends, all built on `lib.nvim`:
---   - "popup"     (default) a scrollable floating window via `lib.nvim.ui.kit`
---   - "buffer"    replaces the current window's buffer with the status buffer
---   - "split"     opens (or reuses) a horizontal split
---   - "vsplit"    opens (or reuses) a vertical split
---   - "clipboard" copies the raw table to the system clipboard
---   - "path"      writes the raw table to a file

---@class ActionStatusView : ActionStatusViewModule
local M = {}

local kit = require("lib.nvim.ui.kit")
local open_named_scratch = require("lib.nvim.window.open_named_scratch")
local copy_to_clipboard = require("lib.nvim.cross.copy_to_clipboard")
local write_to_file = require("lib.nvim.fs.write.to_file")
local notify = require("reposcope.utils.debug").notify

local SCRATCH_NAME = "reposcope://status"
local DEFAULT_PATH_OUT = vim.fn.stdpath("cache") .. "/reposcope/status.txt"

---Renders a list of repository status records into an aligned, human-readable block.
---@param records RepoStatusRecord[] Status records in discovery order
---@return string[] lines Column-aligned overview, one entry per line
function M.render(records)
  local name_w, branch_w = #"REPOSITORY", #"BRANCH"
  for _, r in ipairs(records) do
    name_w = math.max(name_w, #r.name)
    branch_w = math.max(branch_w, #r.branch)
  end

  local fmt = "%-" .. name_w .. "s  %-" .. branch_w .. "s  %-9s  %s"
  local lines = { fmt:format("REPOSITORY", "BRANCH", "AHEAD/BEH", "STATE") }

  for _, r in ipairs(records) do
    local ab = r.has_upstream and ("+%d/-%d"):format(r.ahead, r.behind) or "no upstream"
    local state = r.state
    if r.state == "dirty" then
      state = ("dirty (%d)"):format(r.dirty)
    end
    lines[#lines + 1] = fmt:format(r.name, r.branch, ab, state)
  end

  return lines
end

---Opens the status overview in a scrollable floating window (default output).
---@param lines string[]
---@return nil
local function show_popup(lines)
  kit.surface.open({
    lines = lines,
    title = "Reposcope Status",
    filetype = "reposcope-status",
    nice_quit = true,
    enter = true,
    focusable = true,
    wo = { wrap = false, cursorline = true },
  })
end

---Replaces the current window's buffer with the (reused) status buffer.
---@param lines string[]
---@return nil
local function show_buffer(lines)
  local bufnr = vim.fn.bufnr(SCRATCH_NAME)
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, SCRATCH_NAME)
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "reposcope-status"
  end

  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = false
  vim.api.nvim_win_set_buf(0, bufnr)
end

---Opens (or reuses) a split showing the status buffer.
---@param lines string[]
---@param vertical boolean
---@return nil
local function show_split(lines, vertical)
  open_named_scratch(SCRATCH_NAME, lines, {
    filetype = "reposcope-status",
    split = vertical and "right" or "below",
  })
end

---Copies the raw status table to the system clipboard.
---@param lines string[]
---@return nil
local function show_clipboard(lines)
  local ok = copy_to_clipboard(table.concat(lines, "\n"))
  if ok then
    notify("[reposcope] Status copied to clipboard", 2)
  else
    notify("[reposcope] Failed to copy status to clipboard", 4)
  end
end

---Writes the raw status table to a file (custom path, or a default under stdpath("cache")).
---@param lines string[]
---@param path string|nil
---@return nil
local function show_path(lines, path)
  local target = (path and path ~= "") and vim.fn.expand(path) or DEFAULT_PATH_OUT
  local ok, err = write_to_file(target, table.concat(lines, "\n"))
  if ok then
    notify("[reposcope] Status written to " .. target, 2)
  else
    notify("[reposcope] Failed to write status: " .. tostring(err), 4)
  end
end

---Renders `records` and displays them via the requested output backend.
---@param records RepoStatusRecord[]
---@param opts? { output?: StatusOutputMode, path?: string }
---@return nil
function M.show(records, opts)
  opts = opts or {}
  local mode = opts.output or "popup"
  local lines = M.render(records)

  if mode == "popup" then
    show_popup(lines)
  elseif mode == "buffer" then
    show_buffer(lines)
  elseif mode == "split" then
    show_split(lines, false)
  elseif mode == "vsplit" then
    show_split(lines, true)
  elseif mode == "clipboard" then
    show_clipboard(lines)
  elseif mode == "path" then
    show_path(lines, opts.path)
  else
    notify("[reposcope] Unknown status output mode: " .. tostring(mode), 4)
  end
end

return M
