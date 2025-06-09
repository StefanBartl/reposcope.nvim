local nvim_create_user_command = vim.api.nvim_create_user_command
-- State and Cache
local repository_cache_get = require("reposcope.cache.repository_cache").get
local repository_cache_set = require("reposcope.cache.repository_cache").set
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
-- Project Dependencies
local set_fields = require("reposcope.ui.prompt.prompt_config").set_fields
local get_available_fields = require("reposcope.ui.prompt.prompt_config").get_available_fields
local prompt_filter = require("reposcope.ui.actions.filter_prompt").prompt_filter
local prompt_sort = require("reposcope.ui.actions.sort_prompt").prompt_sort
local fetch_readme_for_selected = require("reposcope.controllers.provider_controller").fetch_readme_for_selected
-- Debugging
local notify = require("reposcope.utils.debug").notify

---This command safely starts the reposcope UI by calling `require("reposcope.init").open_ui()`
---and logs an error notification if an exception occurs.
nvim_create_user_command("ReposcopeStart", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").open_ui()
  end)
  if not ok then
    notify("Error while opening reposcope: " .. err, 4)
  end
end, {
  desc = "Open Reposcope",
})


---This command safely closes the reposcope UI by calling `require("reposcope.init").close_ui()`
---and logs an error notification if an exception occurs.
nvim_create_user_command("ReposcopeClose", function(_)
  local ok, err = pcall(function()
    require("reposcope.init").close_ui()
  end)
  if not ok then
    notify("Error while closing reposcope: " .. err, 4)
  end
end, {
  desc = "Close reposcope",
})


---This command toggles the developer mode for reposcope.
nvim_create_user_command("ReposcopeToggleDev", function()
  require("reposcope.utils.debug").toggle_dev_mode()
end, { desc = "Toggle reposcope dev mode" })


---This command prints the state of developer mode for reposcope.
nvim_create_user_command("ReposcopePrintDev", function()
  print("dev_mode:", require("reposcope.utils.debug").options.dev_mode)
end, { desc = "Print reposcope dev mode" })


--- Command to show statistics directly with :ReposcopeStats
nvim_create_user_command("ReposcopeStats", function()
  require("reposcope.utils.stats").show_stats()
end, {})


--- Sets new prompt fields dynamically (e.g. prefix, keywords, owner) and restarts the UI
--- Sets new prompt fields dynamically and restarts the UI
nvim_create_user_command("ReposcopePromptReload", function(opts)
  local fields = opts.fargs
  local default_fields = { "keywords", "owner", "language" }

  if not fields or #fields == 0 then
    fields = default_fields
    notify("[reposcope] No fields provided. Using default fields: keywords, owner, language", vim.log.levels.WARN)
  end

  set_fields(fields)
  notify("[reposcope] Prompt fields set to: " .. table.concat(fields, ", "), vim.log.levels.INFO)

  -- Restart UI to apply changes
  local ui = require("reposcope.init")
  pcall(ui.close_ui)
  vim.defer_fn(function()
    pcall(ui.open_ui)
  end, 80)
end, {
  desc = "Reload visible prompt fields (e.g. :ReposcopePromptReload prefix keywords)",
  nargs = "*",
  complete = function()
    local fields = get_available_fields()
    table.insert(fields, "default: keywords owner language")
    return fields
  end,
})

-- REF:  Functiuons outsourcen

---Sorts the currently cached repositories by the specified mode and updates the list display.
nvim_create_user_command("ReposcopeSortPrompt", function()
  prompt_sort()
end, {
  desc = "Interactive prompt to sort repositories",
})


---Filters the currently cached repositories based on a case-insensitive substring search.
---Usage: `:ReposcopeFilterRepos <query>`
---@param opts { fargs: string[] } Command arguments
---@return nil
nvim_create_user_command("ReposcopeFilterRepos", function(opts)
  local query = table.concat(opts.fargs, " "):lower()
  if query == "" then
    print("[reposcope] Filter query required")
    return
  end

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
end, {
  nargs = "+",
  desc = "Filter repository list by substring (e.g. :ReposcopeFilterRepos typescript web)",
})


nvim_create_user_command("ReposcopeFilterPrompt", function()
  prompt_filter()
end, {
  desc = "Open floating prompt to filter repositories",
})

--- Prints the number of skipped README fetches due to debounce
nvim_create_user_command("ReposcopeSkippedReadmes", function()
  print("Skipped readme fetches: ", require("reposcope.controllers.provider_controller").get_skipped_fetches())
end, {})

