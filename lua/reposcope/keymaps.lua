---@class UIKeymaps
---@field set_ui_keymaps fun(): nil Applies all UI-related keymaps
---@field unset_ui_keymaps fun(): nil Removes all UI-related keymaps
---@field set_prompt_keymaps fun(): nil Applies all prompt-related keymaps
---@field unset_ui_keymaps fun(): nil Removes all prompt-related keymaps
---@field set_clone_keymaps fun(): nil Applies all clone-related keymaps
---@field unset_clone_keymaps fun(): nil Removes all clone-related keymaps
---@field set_user_keymaps fun(map_cfg?: table, opts?: table): nil Sets user keymaps for opening/closing Reposcope
local M = {}

-- State Modules (Managing UI and Prompt State)
local ui_state = require("reposcope.state.ui.ui_state")
-- Providers (GitHub-specific Functionality)
local gh_readme_manager = require("reposcope.providers.github.readme.readme_manager")
local gh_clone = require("reposcope.providers.github.clone")
-- UI Components (Preview and Navigation)
local readme_viewer = require("reposcope.ui.actions.readme_viewer")
local readme_editor = require("reposcope.ui.actions.readme_editor")
local navigate_list = require("reposcope.ui.prompt.prompt_list_navigate")
local prompt_focus = require("reposcope.ui.prompt.prompt_focus")
-- Utility Modules (Debugging and Notifications)
local notify = require("reposcope.utils.debug").notify
local core = require("reposcope.utils.core")
local defaults = require("reposcope.defaults")

local _registry = {}
local map_over_bufs
local unmap_over_bufs
local clear_registered_keymaps

---Apply all UI-related keymaps
function M.set_ui_keymaps()
  M.set_close_ui_keymaps()
  M.set_prompt_keymaps()
end

---Remove all UI-related keymaps
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
function map_over_bufs(modes, lhs, rhs, bufs, opts, tag)
  opts = opts or {}

  local resolved = {}

  if type(bufs) == "number" then
    table.insert(resolved, bufs)
  elseif core.tbl_islist(bufs) then
    resolved = bufs
  elseif type(bufs) == "table" then
    -- Named map: { prefix = 7, owner = 8, ... }
    for _, buf in pairs(bufs) do
      table.insert(resolved, buf)
    end
  end

  for _, buf in ipairs(resolved) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      vim.keymap.set(modes, lhs, rhs, vim.tbl_extend("force", opts, { buffer = buf }))

      table.insert(_registry, {
        mode = modes,
        lhs = lhs,
        buffer = buf,
        tag = tag,
      })
    end
  end
end


---Unsets a keymap from one or more buffers
---@param mode string|string[] Keymap mode(s)
---@param lhs string Left-hand side keymap
---@param bufs number[]|table|number Buffers to remove keymap from
---@private
function unmap_over_bufs(mode, lhs, bufs)
  local resolved = {}

  if type(bufs) == "number" then
    table.insert(resolved, bufs)
  elseif core.tbl_islist(bufs) then
    resolved = bufs
  elseif type(bufs) == "table" then
    for _, buf in pairs(bufs) do
      table.insert(resolved, buf)
    end
  end

  for _, buf in ipairs(resolved) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.keymap.del, mode, lhs, { buffer = buf })
    end
  end
end


---Set prompt-specific <CR> and arrow key keymaps
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
      mode = {"n", "i"},
      lhs = "<Up>",
      rhs = function()
        navigate_list.navigate_list_in_prompt("up")
        gh_readme_manager.fetch_for_selected()  -- REFACTORE if more providers available
      end,
    },
    {
      mode = {"n", "i"},
      lhs = "<Down>",
      rhs = function()
        navigate_list.navigate_list_in_prompt("down")
        gh_readme_manager.fetch_for_selected()  -- REFACTORE if more providers available
      end,
    },
    {
      mode = {"n", "i"},
      lhs = "<C-w>",
      rhs = function()
        prompt_focus.navigate("next")
      end,
    },
    {
      mode = {"i"},
      lhs = "<C-h>",
      rhs = function()
        prompt_focus.navigate("prev")
      end,
    },
    {
      mode = {"i"},
      lhs = "<S-Tab>",
      rhs = function()
        prompt_focus.navigate("prev")
      end,
    },
    {
      mode = {"i"},
      lhs = "<C-l>",
      rhs = function()
        prompt_focus.navigate("next")
      end,
    },
    {
      mode = {"i"},
      lhs = "<Tab>",
      rhs = function()
        prompt_focus.navigate("next")
      end,
    },
    {
      mode = {"n", "i"},
      lhs = "<C-v>",
      rhs = function()
      readme_viewer.open_viewer()
      end,
    },
   {
      mode = {"n", "i"},
      lhs = "<C-b>",
      rhs = function()
        readme_editor.open_editor()
      end,
    },
    {
      mode = {"n", "i"},
      lhs = "<C-c>",
      rhs = function()
        vim.schedule(function()
          gh_clone.init()  -- REFACTORE if more providers available
        end)
      end,
    },
    {
      mode = {"n", "i"},
      lhs = "<BS>",
      rhs = function()
        local buf = vim.api.nvim_get_current_buf()
        local cursor_pos = vim.api.nvim_win_get_cursor(0)

        if ui_state.buffers.prompt and buf == ui_state.buffers.prompt.keywords and cursor_pos[1] == 2 and cursor_pos[2] == 0 then
          notify("[reposcope] Backspace disabled in column 0 of line 2", 2)
        else
          vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("<BS>", true, false, true), "n", false)
        end
      end,
   }

  }

  for field, buf in pairs(prompt_bufs) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      for _, map in ipairs(mappings) do
        vim.keymap.set(map.mode, map.lhs, map.rhs, { buffer = buf, silent = true })
        table.insert(_registry, {
          mode = map.mode,
          lhs = map.lhs,
          buffer = buf,
          tag = "reposcope_prompt_" .. field,
        })
      end
    end
  end
end

---Apply all keymaps for closing the UI to the relevant buffers.
---These include `<Esc>` and `<C-w>` in normal mode for closing the UI.
---`<Esc>` and `<C-w>` in insert and terminal mode switches to normal mode.
---Registered keymaps are tagged as 'reposcope_ui' for later cleanup.
function M.set_close_ui_keymaps()
  local buffers = {
    ui_state.buffers.backg,
    ui_state.buffers.preview,
    ui_state.buffers.list,
  }

  local prompt_buffers_list = core.flatten_table(ui_state.buffers.prompt)
  vim.list_extend(buffers, prompt_buffers_list)

  -- Normal mode: <Esc> close UI
  map_over_bufs(
    "n", "<Esc>",
    function()
      require("reposcope.init").close_ui()
    end,
    buffers,
    { silent = true },
    "reposcope_ui"
  )

  -- Normal mode: <C-w> close UI
  map_over_bufs(
    "n", "<C-w>",
    function()
      require("reposcope.init").close_ui()
    end,
    buffers,
    { silent = true },
    "reposcope_ui"
  )

  -- Insert, Visual & Terminal Mode: <Esc> -> Normal Mode
  map_over_bufs(
    { "i", "t", "v" }, "<Esc>",
    "<C-\\><C-n>",
    buffers,
    { silent = true },
    "reposcope_ui"
  )

  --Insert, Visual & Terminal Mode: <C-w> -> No operations
  map_over_bufs(
    { "i", "t", "v" }, "<C-w>",
    "<Nop>",
    buffers,
    { silent = true, noremap = true },
    "reposcope_ui"
  )

end

---Clear all registered keymaps with optional tag.
---If no tag is provided, only 'reposcope_'-prefixed tags are accepted.
---@param tag string|nil
---@private
function clear_registered_keymaps(tag)
  if not tag or not tag:find("^reposcope_") then
    notify(
      "[reposcope] Refusing to clear keymaps without valid reposcope_* tag",
      3
    )
    return
  end

  local remaining = {}
  for _, map in ipairs(_registry) do
    if map.tag == tag then
      unmap_over_bufs(map.mode, map.lhs, { map.buffer })
    else
      table.insert(remaining, map)
    end
  end
  _registry = remaining
end

---Remove all prompt-specific keymaps
function M.unset_prompt_keymaps()
  clear_registered_keymaps("reposcope_prompt")
end

---Remove all ui-specific keymaps
function M.unset_close_ui_keymaps()
  clear_registered_keymaps("reposcope_ui")
end


---Sets user keymaps for opening/closing Reposcope
---@param map_cfg? table Optional map override: { rs = "...", rc = "..." }
---@param opts? table Optional map opts (e.g. { silent = false })
---@return nil
function M.set_user_keymaps(map_cfg, opts)
  map_cfg = map_cfg or defaults.options.keymaps
  opts = opts or defaults.options.keymap_opts

  vim.keymap.set("n", map_cfg.open, function()
    local ok, err = pcall(function()
      require("reposcope.init").open_ui()
    end)
    if not ok then
      print("Error while opening reposcope: " .. err)
    end
  end, vim.tbl_extend("force", { desc = "Open Reposcope" }, opts))

  vim.keymap.set("n", map_cfg.close, function()
    local ok, err = pcall(function()
      require("reposcope.init").close_ui()
    end)
    if not ok then
      print("Error while closing reposcope: " .. err)
    end
  end, vim.tbl_extend("force", { desc = "Close Reposcope" }, opts))
end

return M
