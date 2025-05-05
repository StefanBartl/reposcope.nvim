local M = {}

local state = require("reposcope.ui.state")

local _registry = {}
local map_over_bufs
local unmap_over_bufs
local set_prompt_keymaps
local set_close_ui_keymaps
local clear_registered_keymaps
local unset_prompt_keymaps
local unset_close_ui_keymaps

--- Apply all UI-related keymaps
--- @return nil
function M.set_ui_keymaps()
  set_close_ui_keymaps()
  set_prompt_keymaps()
end

--- Remove all UI-related keymaps
--- @return nil
function M.unset_ui_keymaps()
  unset_close_ui_keymaps()
  unset_prompt_keymaps()
end


--- Register and set keymap on multiple buffers
--- @param modes string|string[]
--- @param lhs string
--- @param rhs function|string
--- @param bufs number[]
--- @param opts table|nil
--- @param tag string|nil optional grouping tag
--- @private
function map_over_bufs(modes, lhs, rhs, bufs, opts, tag)
  opts = opts or {}
  for _, buf in ipairs(bufs) do
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

--- Unset a keymap from multiple buffers
--- @param mode string|string[]
--- @param lhs string
--- @param bufs number[]
--- @private
function unmap_over_bufs(mode, lhs, bufs)
  for _, buf in ipairs(bufs) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.keymap.del, mode, lhs, { buffer = buf })
    end
  end
end


--- Set prompt-specific <CR> keymap and register manually
--- @private
--- @return nil
function set_prompt_keymaps()
  local prompt_buf = require("reposcope.ui.state").buffers.prompt
  if type(prompt_buf) ~= "number" or not vim.api.nvim_buf_is_valid(prompt_buf) then
    vim.notify("[reposcope] prompt buffer invalid in set_prompt_keymaps()", vim.log.levels.DEBUG)
    return
  end

  local mappings = {
    {
      mode = "i",
      lhs = "<CR>",
      rhs = function()
        local input = vim.api.nvim_get_current_line()
        require("reposcope.ui.prompt.input").on_enter(input)
      end,
    },
  }

  for _, map in ipairs(mappings) do
    vim.keymap.set(map.mode, map.lhs, map.rhs, { buffer = prompt_buf, silent = true })
    table.insert(_registry, {
      mode = map.mode,
      lhs = map.lhs,
      buffer = prompt_buf,
      tag = "reposcope_prompt",
    })
  end
end


--- Apply all keymaps for closing the UI to the relevant buffers.
--- These include `<Esc>` in insert, normal and terminal mode.
--- Registered keymaps are tagged as 'reposcope_ui' for later cleanup.
--- @private
--- @return nil
function set_close_ui_keymaps()
  map_over_bufs(
    { "i", "n", "t" },
    "<Esc>",
    function()
      require("reposcope.init").close_ui()
    end,
    {
      state.buffers.backg,
      state.buffers.preview,
      state.buffers.prompt,
      state.buffers.list
    },
    { silent = true },
    "reposcope_ui"
  )
end

--- Clear all registered keymaps with optional tag.
--- If no tag is provided, only 'reposcope_'-prefixed tags are accepted.
--- @param tag string|nil
--- @private
function clear_registered_keymaps(tag)
  if not tag or not tag:find("^reposcope_") then
    vim.notify(
      "[reposcope] Refusing to clear keymaps without valid reposcope_* tag",
      vim.log.levels.WARN
    )
    return
  end

  local remaining = {}
  for _, map in ipairs(_registry) do
    if map.tag == tag then
      unmap_over_bufs(map.mode, map.lhs, { map.buffer })
      vim.notify(string.format("[reposcope] cleared keymap %s from buf %d", map.lhs, map.buffer), vim.log.levels.DEBUG)
    else
      table.insert(remaining, map)
    end
  end
  _registry = remaining
end


--- Remove all prompt-specific keymaps
--- @private
--- @return nil
function unset_prompt_keymaps()
  clear_registered_keymaps("reposcope_prompt")
end

--- Remove all ui-specific keymaps
--- @private
--- @return nil
function unset_close_ui_keymaps()
  clear_registered_keymaps("reposcope_ui")
end

return M
