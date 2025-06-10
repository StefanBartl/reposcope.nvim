local nvim_create_user_command = vim.api.nvim_create_user_command
-- State and Cache
local display_repositories = require("reposcope.controllers.list_controller").display_repositories
local restore_relevance_sorting = require("reposcope.cache.repository_cache").restore_relevance_sorting
-- Project Dependencies
local get_available_fields = require("reposcope.ui.prompt.prompt_config").get_available_fields
local reload_prompt = require("reposcope.ui.actions.prompt_reload").reload_prompt
local prompt_filter = require("reposcope.ui.actions.filter_prompt").prompt_filter
local apply_filter = require("reposcope.ui.actions.filter_repos").apply_filter
local fetch_readme_for_selected = require("reposcope.controllers.provider_controller").fetch_readme_for_selected
-- Debugging
local notify = require("reposcope.utils.debug").notify


---This command safely starts the reposcope UI by calling `require("reposcope.init").open_ui()`
---and logs an error notification if an exception occurs.
---
---Usage:
---  `:ReposcopeStart`
---@return nil
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
---Usage:
---  `:ReposcopeClose`
---@return nil
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

---Sets the visible prompt fields dynamically and restarts the UI.
---This command replaces the currently visible prompt inputs (e.g. "keywords", "owner")
---with a new list of fields. If no arguments are provided, the default fields
---`keywords`, `owner`, and `language` are used. After setting the new fields,
---the entire UI is closed and reopened to apply the change.
---
---Usage:
---  `:ReposcopePromptReload prefix keywords`
---  `:ReposcopePromptReload`           (uses default: keywords owner language)
---@return nil
nvim_create_user_command("ReposcopePromptReload", function(opts)
  local fields = opts.fargs
  reload_prompt(fields)
end, {
  desc = "Reload visible prompt fields (e.g. :ReposcopePromptReload prefix keywords)",
  nargs = "*",
  complete = function()
    local fields = get_available_fields()
    table.insert(fields, "default: keywords owner language")
    return fields
  end,
})

---Displays an interactive menu to sort the current repository list.
---Available sort modes are: `"name"`, `"owner"`, `"stars"` and `"relevance"`.
---This uses `vim.ui.select()` to let the user pick a sort mode and applies it to the cached list.
---If `"relevance"` is selected, the original API order is restored from cache.
---
---Usage:
---  :ReposcopeSortPrompt
---@return nil
nvim_create_user_command("ReposcopeSortPrompt", function()
  require("reposcope.ui.actions.sort_prompt").prompt_sort()
end, {
  desc = "Interactive prompt to sort repositories",
})

---Filters the currently cached repositories based on a case-insensitive substring search.
---
---Usage: 
--- `:ReposcopeFilterRepos <query>` or just `:ReposcopeFilterRepos` to reset
---@param opts { fargs: string[] } Command arguments
---@return nil
nvim_create_user_command("ReposcopeFilterRepos", function(opts)
  local query = table.concat(opts.fargs or {}, " ")
  apply_filter(query)
end, {
  nargs = "*",
  desc = "Filter repository list by substring (e.g. :ReposcopeFilterRepos typescript web). Call without args to reset.",
})

---Opens a floating prompt input to filter the current repository list.
---@desc This command allows the user to type a substring interactively, which will
--- be matched against each repository’s "owner/name: description" string.
--- If the input is empty or cancelled, the list remains unchanged.
---
---Usage:
---  ``:ReposcopeFilterPrompt`
---@return nil
nvim_create_user_command("ReposcopeFilterPrompt", function()
  prompt_filter()
end, {
  desc = "Open floating prompt to filter repositories",
})

---Reset the filtered repository list and restore original API result
---This command is equivalent to calling `:ReposcopeFilterRepos` without arguments.
---It reloads the cached original list, re-displays it in the UI, and refreshes the README preview.
---
---Usage:
---  `:ReposcopeFilterClear``
---@return nil
nvim_create_user_command("ReposcopeFilterClear", function()
  restore_relevance_sorting()

  display_repositories()
  fetch_readme_for_selected()

  notify("[reposcope] Filter reset – showing all repositories", 2)
end, {
  desc = "Clear repository filter and show full list again",
})


-- === Usercommands for Debugging and Stats/Metrics ===

---This command toggles the developer mode for reposcope.
---@return nil
nvim_create_user_command("ReposcopeToggleDev", function()
  require("reposcope.utils.debug").toggle_dev_mode()
end, { desc = "Toggle reposcope dev mode" })


---This command prints the state of developer mode for reposcope.
---@return nil
nvim_create_user_command("ReposcopePrintDev", function()
  print("dev_mode:", require("reposcope.utils.debug").options.dev_mode)
end, { desc = "Print reposcope dev mode" })


--- Command to show statistics directly with :ReposcopeStats
---@return nil
nvim_create_user_command("ReposcopeStats", function()
  require("reposcope.utils.stats").show_stats()
end, {})

---Prints the number of skipped README fetches due to debounce
---@return nil
nvim_create_user_command("ReposcopeSkippedReadmes", function()
  print("Skipped readme fetches: ", require("reposcope.controllers.provider_controller").get_skipped_fetches())
end, {})
