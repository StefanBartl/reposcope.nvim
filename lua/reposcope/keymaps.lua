---@class UIKeymaps
---@field set_ui_keymaps fun(): nil Applies all UI-related keymaps
---@field unset_ui_keymaps fun(): nil Removes all UI-related keymaps
---@field set_prompt_keymaps fun(): nil Applies all prompt-related keymaps
---@field unset_ui_keymaps fun(): nil Removes all prompt-related keymaps
---@field set_clone_keymaps fun(): nil Applies all clone-related keymaps
---@field unset_clone_keymaps fun(): nil Removes all clone-related keymaps
local M = {}

local ui_state = require("reposcope.state.ui")
local pops_state = require("reposcope.state.popups")
local navigate_list = require("reposcope.ui.prompt.navigate_list")
local debug = require("reposcope.utils.debug")
local clone = require("reposcope.providers.github.clone")

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

---Register and set keymap on multiple buffers
---@param modes string|string[]
---@param lhs string
---@param rhs function|string
---@param bufs number[]
---@param opts table|nil
---@param tag string|nil optional grouping tag
---@private
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

---Unset a keymap from multiple buffers
---@param mode string|string[]
---@param lhs string
---@param bufs number[]
---@private
function unmap_over_bufs(mode, lhs, bufs)
  for _, buf in ipairs(bufs) do
    if type(buf) == "number" and vim.api.nvim_buf_is_valid(buf) then
      pcall(vim.keymap.del, mode, lhs, { buffer = buf })
    end
  end
end

---Set prompt-specific <CR> and arrow key keymaps
function M.set_prompt_keymaps()
  local prompt_buf = require("reposcope.state.ui").buffers.prompt
  if type(prompt_buf) ~= "number" or not vim.api.nvim_buf_is_valid(prompt_buf) then
    debug.notify("[reposcope] prompt buffer invalid in set_prompt_keymaps()", 1)
    return
  end

  local mappings = {
    {
      mode = "i",
      lhs = "<CR>",
      rhs = function()
        local input = vim.api.nvim_get_current_line()
        -- Removes magnifyer and trims spaces
        local sanitized_query = input:gsub("[\u{f002}]", ""):gsub("^%s*(.-)%s*$", "%1")
        require("reposcope.ui.prompt.input").on_enter(sanitized_query)
      end,
    },
    {
      mode = "i",
      lhs = "<Up>",
      rhs = function()
        navigate_list.navigate_list_in_prompt("up")
        require("reposcope.providers.github.readme").fetch_readme_for_selected()
      end,
    },
    {
      mode = "i",
      lhs = "<Down>",
      rhs = function()
        navigate_list.navigate_list_in_prompt("down")
        require("reposcope.providers.github.readme").fetch_readme_for_selected()
      end,
    },
   {
      mode = "i",
      lhs = "<C-r>",
      rhs = function()
        require("reposcope.ui.preview.readme_viewer").show()
      end,
    },
   {
      mode = "i",
      lhs = "<C-b>",
      rhs = function()
        require("reposcope.ui.preview.readme_buffer").create()
      end,
    },
    {
      mode = "i",
      lhs = "<C-c>",
      rhs = function()
        vim.schedule(function()
          require("reposcope.providers.github.clone").init()
        end)
      end,
    }

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

---Apply all keymaps for closing the UI to the relevant buffers.
---These include `<Esc>` and `<C-w>` in normal mode for closing the UI.
---`<Esc>` and `<C-w>` in insert and terminal mode switches to normal mode.
---Registered keymaps are tagged as 'reposcope_ui' for later cleanup.
function M.set_close_ui_keymaps()
  local buffers = {
    ui_state.buffers.backg,
    ui_state.buffers.preview,
    ui_state.buffers.prompt,
    ui_state.buffers.list
  }

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
    debug.notify(
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

---REF: apply to _registry and map over

---Applies all clone-related keymaps
function M.set_clone_keymaps()
  if pops_state.clone.buf and vim.api.nvim_buf_is_valid(pops_state.clone.buf) then
    vim.keymap.set("n", "<M-CR>", function()
      local path = vim.api.nvim_buf_get_lines(pops_state.clone.buf, 0, 1, false)[1]
      clone.clone_repository(path)
    end, { buffer = pops_state.clone.buf, noremap = true, silent = true })

   vim.keymap.set("i", "<M-CR>", function()
      local path = vim.api.nvim_buf_get_lines(pops_state.clone.buf, 0, 1, false)[1]
      clone.clone_repository(path)
    end, { buffer = pops_state.clone.buf, noremap = true, silent = true })

    vim.keymap.set("n", "<Esc>", function()
      clone.close()
    end, { buffer = pops_state.clone.buf, noremap = true, silent = true })

    vim.keymap.set("n", "<C-q>", function()
      clone.close()
    end, { buffer = pops_state.clone.buf, noremap = true, silent = true })

    vim.keymap.set("i", "<C-q>", function()
      clone.close()
    end, { buffer = pops_state.clone.buf, noremap = true, silent = true })

  else
    vim.debug.notify("No buffer to set keymaps", 1)
  end
end

---Removes all clone-related keymaps
function M.unset_clone_keymaps()
  if pops_state.clone.buf and vim.api.nvim_buf_is_valid(pops_state.clone.buf) then
    pcall(vim.keymap.del, "n", "<M-CR>", { buffer = pops_state.clone.buf })
    pcall(vim.keymap.del, "i", "<M-CR>", { buffer = pops_state.clone.buf })
    pcall(vim.keymap.del, "n", "<Esc>", { buffer = pops_state.clone.buf })
    pcall(vim.keymap.del, "n", "<C-q>", { buffer = pops_state.clone.buf })
    pcall(vim.keymap.del, "i", "<C-q>", { buffer = pops_state.clone.buf })
  end
end

return M
