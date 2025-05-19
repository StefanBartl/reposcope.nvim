---@class UIPreview
---@field show_readme fun(repo_name: string, where: "cache"|"file"|nil, force_markdown?: boolean): nil Displays the README of a repository in the preview window
local M = {}

local readme_cache = require("reposcope.cache.readme_cache")
local ui_state = require("reposcope.state.ui.ui_state")
local debug = require("reposcope.utils.debug")

--- Displays the README of a repository in the preview window
---@param repo_name string The name of the repository
---@param source "cache"|"file"|nil Determines source to load the README from:
--- - "cache": Loads the README from the in-memory cache.
--- - "file": Loads the README from the file cache (persistent storage).
--- - nil: Attempts to load from both (file first, then cache).
---@param force_markdown? boolean If true, forces Markdown highlighting in the preview
function M.show_readme(repo_name, source, force_markdown)
  local content

  if source == "cache" then
    content = readme_cache.get_cached_readme(repo_name)
    if content then
      debug.notify("[reposcope] README loaded from RAM cache: " .. repo_name, 1)
    else
      debug.notify("[reposcope] README not in RAM cache: " .. repo_name, 1)
    end

  elseif source == "file" then
    content = readme_cache.get_fcached_readme(repo_name)
    if content then
      debug.notify("[reposcope] README loaded from File cache: " .. repo_name, 1)
    else
      debug.notify("[reposcope] README not in File cache: " .. repo_name, 1)
    end

  else

    -- Prioritize RAM-Cache > Datei-Cache
    content = readme_cache.get_cached_readme(repo_name)
    if content then
      debug.notify("[reposcope] README loaded from RAM cache: " .. repo_name, 1)
    else
      debug.notify("[reposcope] README not in RAM cache: " .. repo_name, 1)
      -- Wenn nicht im RAM, dann Datei-Cache prüfen
      content = readme_cache.get_fcached_readme(repo_name)
      if content then
        debug.notify("[reposcope] README loaded from File cache: " .. repo_name, 1)
        -- Automatisch in den RAM-Cache laden für schnelleren Zugriff
        readme_cache.cache_readme(repo_name, content)
      else
        debug.notify("[reposcope] README not in File cache: " .. repo_name, 1)
      end
    end
  end

  if not content then
    debug.notify("[reposcope] No content for show_readme", 4)
    return
  end

  local buf = ui_state.buffers.preview
  if not buf then
    debug.notify("[reposcope] Preview buffer not found.", 4)
    return
  end

  -- Use vim.schedule to avoid fast event context issue
  vim.schedule(function()
    -- Apply content to the preview buffer
    vim.api.nvim_buf_set_option(buf, "modifiable", true)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, vim.split(content, "\n"))
    vim.api.nvim_buf_set_option(buf, "modifiable", false)
    vim.api.nvim_buf_set_option(buf, "readonly", true)

    -- Set filetype to markdown only if content is Markdown or forced
    if force_markdown or content:match("^#") or content:match("```") then
      vim.api.nvim_buf_set_option(buf, "filetype", "markdown")
    else
      vim.api.nvim_buf_set_option(buf, "filetype", "text")
    end
  end)
end

return M
