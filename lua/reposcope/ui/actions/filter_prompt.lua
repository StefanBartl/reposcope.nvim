---@module 'reposcope.ui.actions.filter_prompt'
---@brief Opens a floating input for filtering repository list entries
---@description
--- This module shows a `vim.ui.input()` prompt to allow users to filter the
--- currently displayed repository list by text. The input is matched against
--- the "owner/name: description" string and updates the list view accordingly.
--- An empty or missing query resets the original list as received from the API (sorted by relevance).
local M = {}

-- UI + Cache
local repository_cache_get = require("reposcope.cache.repository_cache").get
local repository_cache_set = require("reposcope.cache.repository_cache").set
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local fetch_readme_for_selected = require("reposcope.controllers.provider_controller").fetch_readme_for_selected
local restore_relevance_sorting = require("reposcope.cache.repository_cache").restore_relevance_sorting
-- Debugging
local notify = require("reposcope.utils.debug").notify


---Opens a floating input window to enter a filter query.
---@return nil
function M.prompt_filter()
  local buf = vim.api.nvim_create_buf(false, true) -- scratch, listed=false
  local width = 40
  local height = 1
  local row = math.floor((vim.o.lines - height) / 2)
  local col = math.floor((vim.o.columns - width) / 2)

  local win = vim.api.nvim_open_win(buf, true, {
    relative = "editor",
    width = width,
    height = height,
    row = row,
    col = col,
    style = "minimal",
    border = "rounded",
    title = " Filter Repositories ",
    title_pos = "center",
  })

  -- Setup buffer options
  vim.bo[buf].buftype = "prompt"
  vim.fn.prompt_setprompt(buf, "> ")

  -- Handle <CR> to read input and apply filter
  vim.fn.prompt_setcallback(buf, function(input)
    vim.api.nvim_win_close(win, true)
    if not input or input == "" then return end

    -- Apply filter logic
    local query = input:lower()
    local filtered = {}
    for _, repo in ipairs(repository_cache_get().items or {}) do
      local full = (repo.owner.login .. "/" .. repo.name .. ": " .. (repo.description or "")):lower()
      if full:find(query, 1, true) then
        table.insert(filtered, repo)
      end
    end

    repository_cache_set({ total_count = #filtered, items = filtered }, false)
    display_repositories()
    fetch_readme_for_selected()
  end)

  vim.cmd("startinsert")
end

return M
