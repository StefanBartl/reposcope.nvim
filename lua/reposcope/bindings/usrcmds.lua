---@module 'reposcope.bindings.usrcmds'
---@brief Registers the single `:Reposcope` user command and its subcommands.
---@description
--- Reposcope exposes all of its functionality through one dispatching command,
--- `:Reposcope <subcommand> [args]`, instead of a separate `:ReposcopeXxx`
--- command per action. Subcommands are declared in the `subcommands` table; each
--- entry provides a `desc`, a `run(args)` handler, and an optional `complete`
--- function for argument completion.
---
--- The dispatcher resolves the first token to a subcommand, forwards the
--- remaining `fargs` to its handler, and offers two-level shell completion:
--- subcommand names first, then per-subcommand argument completion (prompt
--- fields, directories, ...). Running `:Reposcope` with no subcommand prints the
--- list of available subcommands.

local composer = require("lib.nvim.usercmd.composer")
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


---Renders a list of repository status records into an aligned, human-readable block.
---@param records RepoStatusRecord[] Status records in discovery order
---@return string rendered Multi-line, column-aligned overview
local function render_status(records)
  -- Determine column widths from the data so the table stays compact but aligned.
  local name_w, branch_w = #"REPOSITORY", #"BRANCH"
  for _, r in ipairs(records) do
    name_w = math.max(name_w, #r.name)
    branch_w = math.max(branch_w, #r.branch)
  end

  local lines = {
    ("%-" .. name_w .. "s  %-" .. branch_w .. "s  %-9s  %s"):format("REPOSITORY", "BRANCH", "AHEAD/BEH", "STATE"),
  }

  for _, r in ipairs(records) do
    local ab = r.has_upstream and ("+%d/-%d"):format(r.ahead, r.behind) or "no upstream"
    local state = r.state
    if r.state == "dirty" then
      state = ("dirty (%d)"):format(r.dirty)
    end
    lines[#lines + 1] = ("%-" .. name_w .. "s  %-" .. branch_w .. "s  %-9s  %s"):format(r.name, r.branch, ab, state)
  end

  return table.concat(lines, "\n")
end

---Reads and displays the git status overview for a directory (or single repository).
---@param path string|nil Optional directory or single-repo override
---@return nil
local function run_status(path)
  require("reposcope.utils.repo_status").status_all(path, function(records, errors)
    if #records > 0 then
      vim.notify("[reposcope] Repository status\n\n" .. render_status(records), vim.log.levels.INFO)
    end
    if #errors > 0 then
      vim.notify(
        ("[reposcope] %d repositor%s could not be read:\n\n%s"):format(
          #errors, #errors == 1 and "y" or "ies", table.concat(errors, "\n")
        ),
        vim.log.levels.WARN
      )
    end
  end)
end

---Updates and displays the result for a directory of cloned repositories.
---@param path string|nil Optional directory override (defaults to the clone directory)
---@return nil
local function run_update(path)
  vim.notify("[reposcope] Updating cloned repositories...", vim.log.levels.INFO)

  require("reposcope.providers.github.clone.clone_updater").update_all(path, function(updated, errors)
    local plural = updated == 1 and "y" or "ies"
    if #errors > 0 then
      vim.notify(
        ("[reposcope] Updated %d repositor%s, %d failed:\n\n%s"):format(updated, plural, #errors, table.concat(errors, "\n\n")),
        vim.log.levels.WARN
      )
    else
      vim.notify(
        ("[reposcope] Updated %d repositor%s successfully"):format(updated, plural),
        vim.log.levels.INFO
      )
    end
  end)
end

---Resets any active repository filter and restores the original relevance-sorted list.
---@return nil
local function run_filter_clear()
  restore_relevance_sorting()
  display_repositories()
  fetch_readme_for_selected()
  notify("[reposcope] Filter reset – showing all repositories", 2)
end


---Directory completion helper for subcommands that take a path argument.
---@param arglead string The partial argument currently being typed
---@return string[]
local function complete_dir(arglead)
  return vim.fn.getcompletion(arglead, "dir")
end

---@class ReposcopeSubcommand
---@field desc string Short description shown in the usage listing
---@field run fun(args: string[]): nil Handler receiving the arguments after the subcommand
---@field complete? fun(arglead: string): string[] Optional argument completion

---Subcommand registry. Each entry is dispatched by `:Reposcope <name>`.
---@type table<string, ReposcopeSubcommand>
local subcommands = {
  start = {
    desc = "Open the Reposcope UI",
    run = function()
      local ok, err = pcall(function()
        require("reposcope.init").open_ui()
      end)
      if not ok then
        notify("Error while opening reposcope: " .. err, 4)
      end
    end,
  },

  close = {
    desc = "Close all Reposcope windows and buffers",
    run = function()
      local ok, err = pcall(function()
        require("reposcope.init").close_ui()
      end)
      if not ok then
        notify("Error while closing reposcope: " .. err, 4)
      end
    end,
  },

  prompt = {
    desc = "Reload visible prompt fields (e.g. :Reposcope prompt prefix keywords)",
    run = function(args)
      reload_prompt(args)
    end,
    complete = function()
      local fields = get_available_fields()
      table.insert(fields, "default: keywords owner language")
      return fields
    end,
  },

  sort = {
    desc = "Open an interactive menu to sort the repository list",
    run = function()
      require("reposcope.ui.actions.sort_prompt").prompt_sort()
    end,
  },

  filter = {
    desc = "Filter the repository list by substring (no args resets the list)",
    run = function(args)
      apply_filter(table.concat(args, " "))
    end,
  },

  ["filter-prompt"] = {
    desc = "Open a floating prompt to filter repositories interactively",
    run = function()
      prompt_filter()
    end,
  },

  ["filter-clear"] = {
    desc = "Clear the active filter and show the full list again",
    run = run_filter_clear,
  },

  update = {
    desc = "Update (fetch + ff-only pull) all cloned repositories in a directory",
    run = function(args)
      run_update(args[1])
    end,
    complete = complete_dir,
  },

  status = {
    desc = "Show the git status overview of all repositories in a directory (or one repository)",
    run = function(args)
      run_status(args[1])
    end,
    complete = complete_dir,
  },

  stats = {
    desc = "Display collected request stats and metrics",
    run = function()
      require("reposcope.utils.stats").show_stats()
    end,
  },

  ["skipped-readmes"] = {
    desc = "Print the number of debounced (skipped) README fetches",
    run = function()
      print("Skipped readme fetches: ", require("reposcope.controllers.provider_controller").get_skipped_fetches())
    end,
  },

  ["toggle-dev"] = {
    desc = "Toggle developer mode (debug logging, internal info)",
    run = function()
      require("reposcope.utils.debug").toggle_dev_mode()
    end,
  },

  ["print-dev"] = {
    desc = "Print whether developer mode is currently active",
    run = function()
      print("dev_mode:", require("reposcope.utils.debug").options.dev_mode)
    end,
  },
}

-- Composer's own bare-`:Reposcope` usage listing (subcommand + .desc per
-- line, derived from the same route tree below) replaces print_usage();
-- its own "unknown subcommand" error replaces the manual notify() above.

---Build one composer route per subcommand, forwarding the leftover tokens
--- into the unchanged entry.run(args). Where entry.complete exists, its
--- candidates are looked up fresh on every <Tab> request via a small custom
--- type per subcommand (not a static snapshot taken once at setup() time --
--- directory listings and prompt fields can both change during a session).
--- entry.complete itself is position-agnostic (offers the same candidates
--- regardless of how many tokens precede arg_lead, e.g. "prompt"'s
--- field-name list), so mapping it onto a single optional first-arg slot
--- recovers real completion there without changing dispatch -- the same
--- tradeoff already used elsewhere for this kind of completer (further
--- tokens still reach entry.run via ctx.rest, just without their own <Tab>
--- completion).
---@return table[]
local function build_routes()
  local routes = {}
  for name, entry in pairs(subcommands) do
    local args
    if entry.complete then
      local type_name = "REPOSCOPE_" .. name:upper():gsub("%-", "_")
      composer.register_type(type_name, {
        validate = function(raw) return true, raw, nil end,
        complete = function(arg_lead)
          local ok, list = pcall(entry.complete, arg_lead)
          return (ok and list) or {}
        end,
      })
      args = { { name = "a1", type = type_name, optional = true } }
    end
    routes[#routes + 1] = {
      path = { name },
      args = args,
      desc = entry.desc,
      run = function(ctx)
        local fargs = {}
        if args and ctx.args.a1 ~= nil then fargs[1] = ctx.args.a1 end
        for _, t in ipairs(ctx.rest) do fargs[#fargs + 1] = t end
        entry.run(fargs)
      end,
    }
  end
  return routes
end

---Registers the single dispatching `:Reposcope` user command.
composer.verb("Reposcope", {
  desc = "Reposcope: <subcommand> [args] (start, close, status, update, filter, prompt, ...)",
  routes = build_routes(),
})
