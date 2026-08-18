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
---
--- The same row also drives git itself: `p`/`P`/`f` push, pull (`--ff-only`)
--- or fetch the repository under the cursor via `utils.repo_actions`. Each
--- action reports success/failure via notification and then re-reads just
--- that repository's status (`utils.repo_status.status_one`) and redraws the
--- table in place, so ahead/behind counts and dirty state stay current
--- without re-scanning the whole directory. A one-line legend of these keys
--- is shown in the window's `winbar`.

---One highlight span produced by `M.render`. Rows and columns are 0-indexed
---byte offsets; `end_col = -1` means "to the end of the line".
---@class StatusHighlight
---@field row integer
---@field col integer
---@field end_col integer
---@field hl string

---@class ActionStatusView : ActionStatusViewModule
local M = {}

local kit = require("lib.nvim.ui.kit")
local map = require("lib.nvim.map")
local open_named_scratch = require("lib.nvim.window.open_named_scratch")
local copy_to_clipboard = require("lib.nvim.cross.copy_to_clipboard")
local write_to_file = require("lib.nvim.fs.write.to_file")
local expand_path = require("lib.nvim.cross.fs.expand_path")
local repo_actions = require("reposcope.utils.repo_actions")
local status_one = require("reposcope.utils.repo_status").status_one
local progress = require("reposcope.utils.progress")
local notify = require("reposcope.utils.debug").notify

---In-flight row actions, keyed by record index -> verb ("push", "pull", ...).
---Rendered in place of the row's state so a slow push isn't several seconds of
---no visible change at all.
---@type table<integer, string>
local _pending = {}

---The most recent overview, kept so the popup can be restored after it is torn
---down to open a README. Without this the records only lived in the popup's
---own closure, so closing it meant re-scanning the whole directory to get back.
---@type { records: RepoStatusRecord[], opts: table, line: integer }|nil
local _last_view

local SCRATCH_NAME = "reposcope://status"
local DEFAULT_PATH_OUT = vim.fn.stdpath("cache") .. "/reposcope/status.txt"
local SPINNER = "⟳"
local NS = vim.api.nvim_create_namespace("reposcope_status")

---Highlight groups for the status table. Linked with `default = true` so a
---colorscheme (or the user) can override any of them without being clobbered
---on the next redraw. The links target semantic diagnostic groups rather than
---the small `ui.config.colortheme` palette, which has no notion of
---"ok/warning/error" and would otherwise force fixed hex values here.
local HL = {
  header = "ReposcopeStatusHeader",
  repo = "ReposcopeStatusRepo",
  branch = "ReposcopeStatusBranch",
  clean = "ReposcopeStatusClean",
  dirty = "ReposcopeStatusDirty",
  ahead = "ReposcopeStatusAhead",
  behind = "ReposcopeStatusBehind",
  diverged = "ReposcopeStatusDiverged",
  muted = "ReposcopeStatusMuted",
  pending = "ReposcopeStatusPending",
}

do
  local links = {
    [HL.header] = "Title",
    [HL.repo] = "Directory",
    [HL.branch] = "Identifier",
    [HL.clean] = "DiagnosticOk",
    [HL.dirty] = "DiagnosticWarn",
    [HL.ahead] = "DiagnosticInfo",
    [HL.behind] = "DiagnosticInfo",
    [HL.diverged] = "DiagnosticError",
    [HL.muted] = "Comment",
    [HL.pending] = "Special",
  }
  for group, target in pairs(links) do
    vim.api.nvim_set_hl(0, group, { link = target, default = true })
  end
end

---@private
---@internal
---Formats a commit timestamp as a compact age ("3h", "2d", "5mo"). Compact
---rather than "3 hours ago" because this sits in a table column, where the
---unit letter carries the same information in a third of the width.
---@param ts integer|nil Unix timestamp, or nil when the repository has no commits
---@return string
local function _relative_age(ts)
  if not ts then return "-" end
  local diff = os.time() - ts
  if diff < 0 then diff = 0 end

  -- math.floor, not `//`: Neovim runs LuaJIT (5.1), which has no integer-division operator.
  if diff < 60 then return "now" end
  if diff < 3600 then return ("%dm"):format(math.floor(diff / 60)) end
  if diff < 86400 then return ("%dh"):format(math.floor(diff / 3600)) end
  if diff < 604800 then return ("%dd"):format(math.floor(diff / 86400)) end
  if diff < 2592000 then return ("%dw"):format(math.floor(diff / 604800)) end
  if diff < 31536000 then return ("%dmo"):format(math.floor(diff / 2592000)) end
  return ("%dy"):format(math.floor(diff / 31536000))
end

---Widest a single column may get before its content is elided. Without a cap,
---one repository on a long topic branch (e.g. "claude/lsp-nvim-plugin-concept-0bfd66")
---stretches the column for every other row, leaving a corridor of blanks across
---the whole table.
local MAX_NAME_W = 28
local MAX_BRANCH_W = 22

---@private
---@internal
---Truncates `s` to `width` display cells, marking elision with an ellipsis.
---@param s string
---@param width integer
---@return string
local function _elide(s, width)
  if vim.fn.strdisplaywidth(s) <= width then return s end
  return vim.fn.strcharpart(s, 0, width - 1) .. "…"
end

---@private
---@internal
---Renders a record's upstream divergence. Empty when the branch tracks an
---upstream and is exactly in sync — that is the common case, and printing
---"+0/-0" on every row was column-wide noise that buried the rows that differ.
---@param r RepoStatusRecord
---@return string
local function _sync_cell(r)
  if not r.has_upstream then return "no upstream" end
  local parts = {}
  if r.ahead > 0 then parts[#parts + 1] = ("↑%d"):format(r.ahead) end
  if r.behind > 0 then parts[#parts + 1] = ("↓%d"):format(r.behind) end
  return table.concat(parts, " ")
end

---Renders a list of repository status records into an aligned, human-readable block.
---
---The SYNC column is omitted entirely when no repository has anything to report
---there, so a directory of perfectly in-sync clones doesn't carry a column of
---blanks. Highlight spans are returned alongside the text (rather than matched
---by a syntax file) because the column offsets are only known here, where the
---widths are computed — keyword matching would also colour a repository
---literally named "clean".
---@param records RepoStatusRecord[] Status records in discovery order
---@return string[] lines Column-aligned overview, one entry per line
---@return StatusHighlight[] highlights Highlight spans, 0-indexed rows and byte columns
function M.render(records)
  local name_w, branch_w, sync_w = #"REPOSITORY", #"BRANCH", 0
  local sync_cells, name_cells, branch_cells = {}, {}, {}
  for i, r in ipairs(records) do
    name_cells[i] = _elide(r.name, MAX_NAME_W)
    branch_cells[i] = _elide(r.branch, MAX_BRANCH_W)
    name_w = math.max(name_w, vim.fn.strdisplaywidth(name_cells[i]))
    branch_w = math.max(branch_w, vim.fn.strdisplaywidth(branch_cells[i]))
    sync_cells[i] = _sync_cell(r)
    sync_w = math.max(sync_w, vim.fn.strdisplaywidth(sync_cells[i]))
  end

  local show_sync = sync_w > 0
  if show_sync then sync_w = math.max(sync_w, #"SYNC") end

  ---@type StatusHighlight[]
  local hls = {}
  local lines = {}

  ---Appends one row, tracking byte offsets so each cell can be highlighted.
  ---@param name string
  ---@param branch string
  ---@param sync string
  ---@param state string
  ---@param age string
  ---@return integer name_end, integer branch_start, integer branch_end, integer state_start, integer state_end, integer age_start
  local function push(name, branch, sync, state, age)
    local parts = { name .. (" "):rep(name_w - vim.fn.strdisplaywidth(name)) }
    local name_end = #parts[1]

    parts[#parts + 1] = "  " .. branch .. (" "):rep(branch_w - vim.fn.strdisplaywidth(branch))
    local branch_start = name_end + 2
    local branch_end = name_end + #parts[#parts]

    if show_sync then
      parts[#parts + 1] = "  " .. sync .. (" "):rep(sync_w - vim.fn.strdisplaywidth(sync))
    end

    local prefix = table.concat(parts)
    local state_start = #prefix + 2
    parts[#parts + 1] = "  " .. state
    local state_end = state_start + #state

    local padded_state = state .. (" "):rep(math.max(0, 12 - vim.fn.strdisplaywidth(state)))
    parts[#parts] = "  " .. padded_state
    local age_start = #table.concat(parts) + 2
    parts[#parts + 1] = "  " .. age

    lines[#lines + 1] = (table.concat(parts):gsub("%s+$", ""))
    return name_end, branch_start, branch_end, state_start, state_end, age_start
  end

  push("REPOSITORY", "BRANCH", "SYNC", "STATE", "LAST COMMIT")
  hls[#hls + 1] = { row = 0, col = 0, end_col = -1, hl = HL.header }

  for i, r in ipairs(records) do
    local state = r.state
    if r.state == "dirty" then state = ("dirty (%d)"):format(r.dirty) end

    local pending = _pending[i]
    if pending then state = ("%s %s..."):format(SPINNER, pending) end

    local name_end, branch_start, branch_end, state_start, state_end, age_start =
        push(name_cells[i], branch_cells[i], sync_cells[i], state, _relative_age(r.last_commit))

    local row = #lines - 1
    hls[#hls + 1] = { row = row, col = 0, end_col = name_end, hl = HL.repo }
    hls[#hls + 1] = { row = row, col = branch_start, end_col = branch_end, hl = HL.branch }

    local state_hl = pending and HL.pending or HL[r.state] or HL.muted
    hls[#hls + 1] = { row = row, col = state_start, end_col = state_end, hl = state_hl }
    hls[#hls + 1] = { row = row, col = age_start, end_col = -1, hl = HL.muted }
  end

  return lines, hls
end

---Builds the one-line summary used as the popup title.
---@param records RepoStatusRecord[]
---@return string
function M.summary(records)
  local dirty, out_of_sync = 0, 0
  for _, r in ipairs(records) do
    if r.dirty > 0 then dirty = dirty + 1 end
    if r.ahead > 0 or r.behind > 0 then out_of_sync = out_of_sync + 1 end
  end

  local parts = { ("%d repo%s"):format(#records, #records == 1 and "" or "s") }
  if dirty > 0 then parts[#parts + 1] = ("%d dirty"):format(dirty) end
  if out_of_sync > 0 then parts[#parts + 1] = ("%d out of sync"):format(out_of_sync) end
  return "Reposcope Status — " .. table.concat(parts, " · ")
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
  if not require("lib.nvim.fs.is_readable_file")(readme_path) then
    notify("[reposcope] No README.md found for " .. record.name, 3)
    return
  end

  -- Remember where we were before the popup is torn down, so `q` can put the
  -- overview back on the same row.
  if _last_view then
    _last_view.line = vim.api.nvim_win_get_cursor(0)[1]
  end

  kit.confirm({
    question = ('Open README.md of "%s"?'):format(record.name),
    on_answer = function(yes)
      if not yes then return end
      if before_open then before_open() end
      vim.cmd.edit(vim.fn.fnameescape(readme_path))

      -- Bound explicitly rather than via a BufWinLeave autocmd: navigating away
      -- with `:edit other` would also fire that, and silently resurrecting the
      -- dashboard on an unrelated buffer switch is worse than not restoring it.
      if not _last_view then return end
      local buf = vim.api.nvim_get_current_buf()
      map("n", "q", function()
        vim.cmd("bwipeout")
        M.reopen()
      end, { buffer = buf, nowait = true }, "Close README and return to the Reposcope status overview")
      notify("[reposcope] q returns to the status overview", 3)
    end,
  })
end

---@private
---@internal
---Replaces `bufnr`'s content with `lines` and applies `highlights`, toggling
---`modifiable` only for the duration of the write so read-only status buffers
---stay locked afterwards.
---@param bufnr integer
---@param lines string[]
---@param highlights? StatusHighlight[]
---@return nil
local function _set_buffer_lines(bufnr, lines, highlights)
  if not vim.api.nvim_buf_is_valid(bufnr) then return end
  local was_modifiable = vim.bo[bufnr].modifiable
  vim.bo[bufnr].modifiable = true
  vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
  vim.bo[bufnr].modifiable = was_modifiable

  vim.api.nvim_buf_clear_namespace(bufnr, NS, 0, -1)
  for _, h in ipairs(highlights or {}) do
    pcall(vim.api.nvim_buf_set_extmark, bufnr, NS, h.row, h.col, {
      end_col = h.end_col >= 0 and h.end_col or nil,
      end_row = h.end_col < 0 and (h.row + 1) or nil,
      hl_group = h.hl,
    })
  end
end

---@private
---@internal
---Redraws the whole table into `bufnr`, preserving the cursor position.
---@param bufnr integer
---@param records RepoStatusRecord[]
---@return nil
local function _redraw(bufnr, records)
  local win = vim.fn.bufwinid(bufnr)
  local cursor = (win ~= -1) and vim.api.nvim_win_get_cursor(win) or nil
  local lines, hls = M.render(records)
  _set_buffer_lines(bufnr, lines, hls)
  if cursor then pcall(vim.api.nvim_win_set_cursor, win, cursor) end
end

---@private
---@internal
---Re-reads `records[idx]`'s git status and redraws `bufnr`, preserving the
---cursor position. Called after a push/pull/fetch settles so ahead/behind and
---dirty state reflect the outcome without re-scanning every repository.
---@param bufnr integer
---@param records RepoStatusRecord[]
---@param idx integer
---@return nil
local function _refresh_row(bufnr, records, idx)
  local record = records[idx]
  if not record then return end

  status_one(record.path, function(new_record)
    vim.schedule(function()
      if new_record then records[idx] = new_record end
      _redraw(bufnr, records)
    end)
  end)
end

---@private
---@internal
---Runs a single-repository git action against the row under the cursor,
---notifies the outcome, then refreshes that row.
---@param bufnr integer
---@param records RepoStatusRecord[]
---@param verb string Human-readable action name, used in notifications
---@param action_fn fun(repo: string, on_done: fun(ok: boolean, err: string|nil): nil): nil One of `repo_actions.push/pull/fetch`
---@return nil
local function _run_row_action(bufnr, records, verb, action_fn)
  local line = vim.api.nvim_win_get_cursor(0)[1]
  local idx = line - 1
  local record = records[idx]
  if not record then return end
  if _pending[idx] then
    notify(("[reposcope] %s: %s already running"):format(record.name, _pending[idx]), 3)
    return
  end

  -- Level 3: `utils.debug.notify` drops anything below WARN unless dev mode is
  -- on, so an INFO-level "push ..." would be invisible in normal use -- which
  -- is exactly the silence this feedback is meant to fill.
  notify(("[reposcope] %s %s ..."):format(verb, record.name), 3)
  local handle = progress.create(("%s %s"):format(verb, record.name))

  _pending[idx] = verb
  _redraw(bufnr, records)

  action_fn(record.path, function(ok, err)
    vim.schedule(function()
      _pending[idx] = nil
      if ok then
        notify(("[reposcope] %s: %s done"):format(record.name, verb), 3)
        if handle then handle:finish(("%s %s done"):format(verb, record.name)) end
      else
        notify(("[reposcope] %s: %s failed - %s"):format(record.name, verb, err or "unknown error"), 4)
        if handle then handle:finish(("%s %s failed"):format(verb, record.name)) end
      end
      _refresh_row(bufnr, records, idx)
    end)
  end)
end

---Context handed to every row keymap handler.
---@class StatusRowContext
---@field bufnr integer
---@field records RepoStatusRecord[]
---@field before_open? fun(): nil

---One interactive binding on a status row.
---@class StatusRowKeymap
---@field keys string[] Every lhs that triggers this action
---@field label string Short "key desc" text for the winbar legend (nil = hidden)
---@field desc string Full description, used as the keymap's `desc`
---@field run fun(ctx: StatusRowContext): nil

---Row bindings, and the single source of truth for the winbar legend below —
---adding a key here makes it live *and* documents it, instead of the legend
---being a hand-maintained string that silently drifts out of date.
---@type StatusRowKeymap[]
local ROW_KEYMAPS = {
  {
    keys = { "<CR>", "<2-LeftMouse>" },
    label = "<CR> README",
    desc = "Open README.md of repository under cursor",
    run = function(ctx)
      local record = _record_at_cursor(ctx.records)
      if record then _open_readme(record, ctx.before_open) end
    end,
  },
  {
    keys = { "p" },
    label = "p Push",
    desc = "Push repository under cursor",
    run = function(ctx) _run_row_action(ctx.bufnr, ctx.records, "push", repo_actions.push) end,
  },
  {
    keys = { "P" },
    label = "P Pull",
    desc = "Pull repository under cursor",
    run = function(ctx) _run_row_action(ctx.bufnr, ctx.records, "pull", repo_actions.pull) end,
  },
  {
    keys = { "f" },
    label = "f Fetch",
    desc = "Fetch repository under cursor",
    run = function(ctx) _run_row_action(ctx.bufnr, ctx.records, "fetch", repo_actions.fetch) end,
  },
}

---@private
---@internal
---Builds the winbar legend from `ROW_KEYMAPS`, so it can never list a key that
---isn't actually bound. Keys are highlighted separately from their labels via
---`%#Group#` items, which the winbar understands natively.
---@return string
local function _legend()
  local parts = {}
  for _, entry in ipairs(ROW_KEYMAPS) do
    if entry.label then
      local key, text = entry.label:match("^(%S+)%s+(.*)$")
      parts[#parts + 1] = ("%%#%s#%s %%#%s#%s"):format(HL.pending, key, HL.muted, text)
    end
  end
  return "  " .. table.concat(parts, ("  %%#%s#│  "):format(HL.muted))
end

---@private
---@internal
---Wires every binding in `ROW_KEYMAPS` onto a status buffer, all acting on the
---repository row under the cursor. Safe to call repeatedly on a reused buffer —
---later calls just overwrite the mappings with closures over the current `records`.
---@param bufnr integer
---@param records RepoStatusRecord[]
---@param before_open? fun(): nil Passed through to `_open_readme`
---@return nil
local function _attach_row_keymaps(bufnr, records, before_open)
  local ctx = { bufnr = bufnr, records = records, before_open = before_open }
  local mo = { buffer = bufnr, nowait = true }

  for _, entry in ipairs(ROW_KEYMAPS) do
    for _, lhs in ipairs(entry.keys) do
      map("n", lhs, function() entry.run(ctx) end, mo, entry.desc)
    end
  end
end

---@private
---@internal
---Opens the status overview in a scrollable floating window (default output).
---@param lines string[]
---@param hls StatusHighlight[]
---@param records RepoStatusRecord[]
---@return nil
local function show_popup(lines, hls, records)
  local surf = kit.surface.open({
    lines = lines,
    title = M.summary(records),
    filetype = "reposcope-status",
    nice_quit = true,
    enter = true,
    focusable = true,
    -- +1 accounts for the winbar legend, which otherwise eats one row of
    -- content out of a height sized exactly to the number of status lines
    -- (make_scratch still clamps this to the editor's available height).
    height = #lines + 1,
    wo = { wrap = false, cursorline = true, winbar = _legend() },
  })
  if not surf then return end
  _set_buffer_lines(surf.bufnr, lines, hls)
  _attach_row_keymaps(surf.bufnr, records, function() surf:close() end)
end

---@private
---@internal
---Replaces the current window's buffer with the (reused) status buffer.
---@param lines string[]
---@param hls StatusHighlight[]
---@param records RepoStatusRecord[]
---@return nil
local function show_buffer(lines, hls, records)
  local bufnr = vim.fn.bufnr(SCRATCH_NAME)
  if bufnr == -1 or not vim.api.nvim_buf_is_valid(bufnr) then
    bufnr = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_name(bufnr, SCRATCH_NAME)
    vim.bo[bufnr].buftype = "nofile"
    vim.bo[bufnr].bufhidden = "hide"
    vim.bo[bufnr].swapfile = false
    vim.bo[bufnr].filetype = "reposcope-status"
  end

  _set_buffer_lines(bufnr, lines, hls)
  vim.bo[bufnr].modifiable = false
  vim.api.nvim_win_set_buf(0, bufnr)
  vim.api.nvim_set_option_value("winbar", _legend(), { win = 0 })
  _attach_row_keymaps(bufnr, records)
end

---@private
---@internal
---Opens (or reuses) a split showing the status buffer.
---@param lines string[]
---@param hls StatusHighlight[]
---@param vertical boolean
---@param records RepoStatusRecord[]
---@return nil
local function show_split(lines, hls, vertical, records)
  local bufnr, winid = open_named_scratch(SCRATCH_NAME, lines, {
    filetype = "reposcope-status",
    split = vertical and "right" or "below",
  })
  _set_buffer_lines(bufnr, lines, hls)
  vim.api.nvim_set_option_value("winbar", _legend(), { win = winid })
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
  local lines, hls = M.render(records)

  _last_view = { records = records, opts = opts, line = (_last_view or {}).line or 2 }

  if mode == "popup" then
    show_popup(lines, hls, records)
  elseif mode == "buffer" then
    show_buffer(lines, hls, records)
  elseif mode == "split" then
    show_split(lines, hls, false, records)
  elseif mode == "vsplit" then
    show_split(lines, hls, true, records)
  elseif mode == "clipboard" then
    show_clipboard(lines)
  elseif mode == "path" then
    show_path(lines, opts.path)
  else
    notify("[reposcope] Unknown status output mode: " .. tostring(mode), 4)
  end

  -- Restore the row the user was on before the overview was last torn down.
  local win = vim.api.nvim_get_current_win()
  local count = vim.api.nvim_buf_line_count(vim.api.nvim_win_get_buf(win))
  pcall(vim.api.nvim_win_set_cursor, win, { math.min(_last_view.line, count), 0 })
end

---Re-displays the most recent overview, using the cached records rather than
---re-scanning the directory. Used to bring the dashboard back after it was
---closed to open a repository's README.
---@return boolean shown False when nothing has been displayed yet this session
function M.reopen()
  if not _last_view then
    notify("[reposcope] No status overview to return to", 3)
    return false
  end
  M.show(_last_view.records, _last_view.opts)
  return true
end

return M
