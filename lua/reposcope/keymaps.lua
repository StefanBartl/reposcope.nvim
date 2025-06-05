---@module 'reposcope.keymaps'
---@brief Definition of the keymaps for the Reposcope Plugin

---@class UIKeymaps: UIKeymapsModule
local M = {}

-- Vim Utilities
local tbl_extend = vim.tbl_extend
local list_extend = vim.list_extend
local set_km = vim.keymap.set
local del_km = vim.keymap.del
local nvim_get_current_buf = vim.api.nvim_get_current_buf
local nvim_win_get_cursor = vim.api.nvim_win_get_cursor
local nvim_buf_is_valid = vim.api.nvim_buf_is_valid
local nvim_feedkeys = vim.api.nvim_feedkeys
local nvim_replace_termcodes = vim.api.nvim_replace_termcodes
--- Project dependencies
local cfg_get_option = require("reposcope.config").get_option
local ui_state = require("reposcope.state.ui.ui_state")
local fetch_readme_for_selected = require("reposcope.controllers.provider_controller").fetch_readme_for_selected
local prompt_and_clone = require("reposcope.controllers.provider_controller").prompt_and_clone
local open_viewer = require("reposcope.ui.actions.readme_viewer").open_viewer
local open_editor = require("reposcope.ui.actions.readme_editor").open_editor
local navigate_list_in_prompt = require("reposcope.ui.prompt.prompt_list_navigate").navigate_list_in_prompt
local navigate = require("reposcope.ui.prompt.prompt_focus").navigate
local notify = require("reposcope.utils.debug").notify
local flatten_table = require("reposcope.utils.core").flatten_table
local tbl_islist = require("reposcope.utils.core").tbl_islist

local _registry = {}
local map_over_bufs
local unmap_over_bufs

---Apply all UI-related keymaps
---@return nil
function M.set_ui_keymaps()
  M.set_close_ui_keymaps()
  M.set_prompt_keymaps()
end

---Remove all UI-related keymaps
---@return nil
function M.unset_ui_keymaps()
  M.unset_close_ui_keymaps()
  M.unset_prompt_keymaps()
end

---Sets the same keymap for multiple buffers.
---@param modes string|string[] Keymap modes (e.g. "n", "i", {"n", "i"})
---@param lhs string Key combination
---@param rhs string|function Action or callback
---@param bufs number[]|table|number List or map of buffer handles, or single buffer
---@param opts table? Keymap options
---@param tag string? Optional tag to store in registry
---@return nil
function map_over_bufs(modes, lhs, rhs, bufs, opts, tag)
  opts = opts or {}

  local resolved = {}

  if type(bufs) == "number" then
    table.insert(resolved, bufs)
  elseif tbl_islist(bufs) then
    resolved = bufs
  elseif type(bufs) == "table" then
    -- Named map: { prefix = 7, owner = 8, ... }
    for _, buf in pairs(bufs) do
      table.insert(resolved, buf)
    end
  end


  for i = 1, #resolved do
    local buf = resolved[i]
    if type(buf) == "number" and nvim_buf_is_valid(buf) then
      local map_opts = tbl_extend("force", opts, { buffer = buf })

      set_km(modes, lhs, rhs, map_opts)

      _registry[#_registry + 1] = {
        mode = modes,
        lhs = lhs,
        buffer = buf,
        tag = tag,
      }
    end
  end
end

---@private
---Unsets a keymap from one or more buffers
---@param mode string|string[] Keymap mode(s)
---@param lhs string Left-hand side keymap
---@param bufs number[]|table|number Buffers to remove keymap from
---@return nil
function unmap_over_bufs(mode, lhs, bufs)
  local resolved = {}

  if type(bufs) == "number" then
    table.insert(resolved, bufs)
  elseif tbl_islist(bufs) then
    resolved = bufs
  elseif type(bufs) == "table" then
    for _, buf in pairs(bufs) do
      table.insert(resolved, buf)
    end
  end

  for i = 1, #resolved do
    local buf = resolved[i]
    if type(buf) == "number" and nvim_buf_is_valid(buf) then
      local ok, err = pcall(del_km, mode, lhs, { buffer = buf })
      if not ok then
        notify("[reposcope] Failed to remove keymap: " .. tostring(err), 2)
      end
    end
  end
end

---Set prompt-specific <CR> and arrow key keymaps
---@return nil
function M.set_prompt_keymaps()
  local prompt_bufs = ui_state.buffers.prompt
  if type(prompt_bufs) ~= "table" then
    notify("[reposcope] prompt buffers missing or invalid in set_prompt_keymaps()", 1)
    return
  end

  local mappings = {
    {
      mode = "i",
      lhs = "<CR>",
      rhs = function()
        require("reposcope.ui.prompt.prompt_input").on_enter()
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<Up>",
      rhs = function()
        navigate_list_in_prompt("up")
        fetch_readme_for_selected()
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<Down>",
      rhs = function()
        navigate_list_in_prompt("down")

        fetch_readme_for_selected()
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<C-w>",
      rhs = function()
        navigate("next")
      end,
    },
    {
      mode = { "i" },
      lhs = "<C-h>",
      rhs = function()
        navigate("prev")
      end,
    },
    {
      mode = { "i" },
      lhs = "<S-Tab>",
      rhs = function()
        navigate("prev")
      end,
    },
    {
      mode = { "i" },
      lhs = "<C-l>",
      rhs = function()
        navigate("next")
      end,
    },
    {
      mode = { "i" },
      lhs = "<Tab>",
      rhs = function()
        navigate("next")
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<C-v>",
      rhs = function()
        open_viewer()
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<C-b>",
      rhs = function()
        open_editor()
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<C-c>",
      rhs = function()
        prompt_and_clone()
      end,
    },
    {
      mode = { "n", "i" },
      lhs = "<BS>",
      rhs = function()
        local buf = nvim_get_current_buf()
        local cursor_pos = nvim_win_get_cursor(0)

        if ui_state.buffers.prompt and buf == ui_state.buffers.prompt.keywords and cursor_pos[1] == 2 and cursor_pos[2] == 0 then
          notify("[reposcope] Backspace disabled in column 0 of line 2", 2)
        else
          nvim_feedkeys(nvim_replace_termcodes("<BS>", true, false, true), "n", false)
        end
      end,
    }

  }

  for field, buf in pairs(prompt_bufs) do
    if type(buf) == "number" and nvim_buf_is_valid(buf) then
      for i = 1, #mappings do
        local map = mappings[i]

        set_km(map.mode, map.lhs, map.rhs, { buffer = buf, silent = true })

        _registry[#_registry + 1] = {
          mode = map.mode,
          lhs = map.lhs,
          buffer = buf,
          tag = "reposcope_prompt_" .. field,
        }
      end
    end
  end
end

---Apply all keymaps for closing the UI to the relevant buffers.
---These include `<Esc>` and `<C-w>` in normal mode for closing the UI.
---`<Esc>` and `<C-w>` in insert and terminal mode switches to normal mode.
---Registered keymaps are tagged as 'reposcope_ui' for later cleanup.
---@return nil
function M.set_close_ui_keymaps()
  local buffers = {
    ui_state.buffers.backg,
    ui_state.buffers.preview,
    ui_state.buffers.list,
  }

  local prompt_buffers_list = flatten_table(ui_state.buffers.prompt)
  list_extend(buffers, prompt_buffers_list)

  -- <Esc> close UI
  map_over_bufs(
    "n", "<Esc>",
    function()
      require("reposcope.init").close_ui()
    end,
    buffers,
    { silent = true },
    "reposcope_ui"
  )

  -- <Esc> -> Normal Mode
  map_over_bufs(
    { "i", "t", "v" }, "<Esc>",
    "<C-\\><C-n>",
    buffers,
    { silent = true },
    "reposcope_ui"
  )

  -- <C-w> close UI
  map_over_bufs(
    "n", "<C-w>",
    function()
      require("reposcope.init").close_ui()
    end,
    buffers,
    { silent = true },
    "reposcope_ui"
  )


  -- <C-w> -> No operations
  map_over_bufs(
    { "i", "t", "v" }, "<C-w>",
    "<Nop>",
    buffers,
    { silent = true, noremap = true },
    "reposcope_ui"
  )
end

---@private
---Clear all registered keymaps with optional tag.
---If no tag is provided, only 'reposcope_'-prefixed tags are accepted.
---@param tag string|nil
---@return nil
local function _clear_registered_keymaps(tag)
  if type(tag) ~= "string" or not tag:find("^reposcope_") then
    notify("[reposcope] Refusing to clear keymaps without valid reposcope_* tag", 3)
    return
  end

  local remaining = {}
  local unmap = unmap_over_bufs

  for i = 1, #_registry do
    local map = _registry[i]
    if map.tag == tag then
      unmap(map.mode, map.lhs, { map.buffer })
    else
      remaining[#remaining + 1] = map
    end
  end

  _registry = remaining
end

---Remove all prompt-specific keymaps
---@return nil
function M.unset_prompt_keymaps()
  _clear_registered_keymaps("reposcope_prompt")
end

---Remove all ui-specific keymaps
---@return nil
function M.unset_close_ui_keymaps()
  _clear_registered_keymaps("reposcope_ui")
end

---Sets user keymaps for opening/closing Reposcope
---@param map_cfg? table Optional map override: { open = "...", close = "..." }
---@param opts? table Optional map opts (e.g. { silent = false })
---@return nil
function M.set_user_keymaps(map_cfg, opts)
  map_cfg = map_cfg or cfg_get_option("keymaps")
  opts = opts or cfg_get_option("keymap_opts")

  set_km("n", map_cfg.open, function()
    local ok, err = pcall(function()
      require("reposcope.init").open_ui()
    end)
    if not ok then
      print("Error while opening Reposcope: " .. err)
    end
  end, tbl_extend("force", { desc = "Open Reposcope" }, opts))

  set_km("n", map_cfg.close, function()
    local ok, err = pcall(function()
      require("reposcope.init").close_ui()
    end)
    if not ok then
      print("Error while closing Reposcope: " .. err)
    end
  end, tbl_extend("force", { desc = "Close Reposcope" }, opts))
end

return M
