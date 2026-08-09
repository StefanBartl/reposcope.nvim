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
---
--- On every interactive backend (popup/buffer/split/vsplit), the repository row
--- under the cursor can be opened: `<CR>` or a double-click (`<2-LeftMouse>`)
--- asks for confirmation via `lib.nvim.ui.kit`'s button-confirm dialog, then
--- opens that repository's `README.md` (`:edit`). Rows with no readable
--- `README.md` are a silent no-op past a notification — there is nothing to
--- confirm opening.

---@class ActionStatusView : ActionStatusViewModule
local M = {}

local kit = require("lib.nvim.ui.kit")
local map = require("lib.nvim.map")
local open_named_scratch = require("lib.nvim.window.open_named_scratch")
local copy_to_clipboard = require("lib.nvim.cross.copy_to_clipboard")
local write_to_file = require("lib.nvim.fs.write.to_file")
local expand_path = require("lib.nvim.cross.fs.expand_path")
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
    if r.state == "dirty" then state = ("dirty (%d)"):format(r.dirty) end
    lines[#lines + 1] = fmt:format(r.name, r.branch, ab, state)
  end

  return lines
end

---@private
---@internal
---Resolves the status row under the cursor to its record. Line 1 is always
---the header (see `M.render`), so the record index is `cursor_line - 1`.
---@param records RepoStatusRecord[]
---@return RepoStatusRecord|nil
local function _record_at_cursor(records)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  return records[line - 1]
end

---@private
---@internal
---Confirms with the user, then opens `record`'s README.md (`:edit`). A
---missing README.md is reported and treated as a no-op — there is nothing
---to confirm opening.
---@param record RepoStatusRecord
---@param before_open? fun(): nil Called right before the file is opened (e.g. to close a popup)
---@return nil
local function _open_readme(record, before_open)
  local readme_path = record.path .. "/README.md"
  if vim.fn.filereadable(readme_path) ~= 1 then
    notify("[reposcope] No README.md found for " .. record.name, 3)
    return
  end

  kit.confirm({
    question = ('Open README.md of "%s"?'):format(record.name),
    on_answer = function(yes)
      if not yes then return end
      if before_open then before_open() end
      vim.cmd.edit(vim.fn.fnameescape(readme_path))
    end,
  })
end

---@private
---@internal
---Wires `<CR>` and double-click on a status buffer to open the README.md of
---the repository under the cursor (after confirmation). Safe to call
---repeatedly on a reused buffer — later calls just overwrite the mapping
---with a closure over the current `records`.
---@param bufnr integer
---@param records RepoStatusRecord[]
---@param before_open? fun(): nil Passed through to `_open_readme`
---@return nil
local function _attach_row_keymaps(bufnr, records, before_open)
  local function activate()
    local record = _record_at_cursor(records)
    if record then _open_readme(record, before_open) end
  end

  local mo = { buffer = bufnr, nowait = true }
  map("n", "<CR>", activate, mo, "Open README.md of repository under cursor")
  map("n", "<2-LeftMouse>", activate, mo, "Open README.md of repository under cursor")
end

---@private
---@internal
---Opens the status overview in a scrollable floating window (default output).
---@param lines string[]
---@param records RepoStatusRecord[]
---@return nil
local function show_popup(lines, records)
  local surf = kit.surface.open({
    lines = lines,
    title = "Reposcope Status",
    filetype = "reposcope-status",
    nice_quit = true,
    enter = true,
    focusable = true,
    wo = { wrap = false, cursorline = true },
  })
  if surf then
    _attach_row_keymaps(surf.bufnr, records, function() surf:close() end)
  end
end

---@private
---@internal
---Replaces the current window's buffer with the (reused) status buffer.
---@param lines string[]
---@param records RepoStatusRecord[]
---@return nil
local function show_buffer(lines, records)
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
  _attach_row_keymaps(bufnr, records)
end

---@private
---@internal
---Opens (or reuses) a split showing the status buffer.
---@param lines string[]
---@param vertical boolean
---@param records RepoStatusRecord[]
---@return nil
local function show_split(lines, vertical, records)
  local bufnr = open_named_scratch(SCRATCH_NAME, lines, {
    filetype = "reposcope-status",
    split = vertical and "right" or "below",
  })
  _attach_row_keymaps(bufnr, records)
end

---@private
---@internal
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

---@private
---@internal
---Writes the raw status table to a file (custom path, or a default under stdpath("cache")).
---@param lines string[]
---@param path string|nil
---@return nil
local function show_path(lines, path)
  local target = (path and path ~= "") and expand_path(path) or DEFAULT_PATH_OUT
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
    show_popup(lines, records)
  elseif mode == "buffer" then
    show_buffer(lines, records)
  elseif mode == "split" then
    show_split(lines, false, records)
  elseif mode == "vsplit" then
    show_split(lines, true, records)
  elseif mode == "clipboard" then
    show_clipboard(lines)
  elseif mode == "path" then
    show_path(lines, opts.path)
  else
    notify("[reposcope] Unknown status output mode: " .. tostring(mode), 4)
  end
end

return M
