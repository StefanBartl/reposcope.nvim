# Commands

All functionality is exposed through a single `:Reposcope <subcommand> [args]`
command. Run `:Reposcope` without arguments to print the list of available
subcommands; tab-completion offers the subcommand names first, then
per-subcommand arguments (prompt fields, directories, ...).

Launch Reposcope UI:

```vim
:Reposcope start
```

Or map it in your Neovim config:

```lua
vim.keymap.set("n", "<leader>rs", function()
  vim.cmd("Reposcope start")
end, { desc = "Open Reposcope" })
```

## Table of Contents

- [UI Keymaps](#ui-keymaps)
- [Available Commands](#available-commands)
  - [:Reposcope prompt {fields}](#reposcope-prompt-fields)
  - [:Reposcope filter {text}](#reposcope-filter-text)
  - [:Reposcope filter-prompt](#reposcope-filter-prompt)
  - [:Reposcope update [dir]](#reposcope-update-dir)
  - [:Reposcope status [dir]](#reposcope-status-dir)

---

## UI Keymaps

| Key           | Mode | Action                                |
| ------------- | ---- | ------------------------------------- |
| `<Esc>`       | any  | Close Reposcope UI                    |
| `<Up>/<Down>` | n/i  | Navigate repository list              |
| `<C-v>`       | n/i  | View README in floating window        |
| `<C-b>`       | n/i  | Open README in editable hidden buffer |
| `<C-c>`       | n/i  | Clone selected repository             |
| `<Tab>`       | i    | Cycle to next prompt field            |
| `<S-Tab>`     | i    | Cycle to previous prompt field        |

All prompt keymaps above are configurable and disableable via `prompt_keymaps`,
and are picked up automatically by [which-key](https://github.com/folke/which-key.nvim)
if installed. See [BINDINGS.md](BINDINGS.md) for the full, authoritative
list of keymaps, user commands, and autocommands.

---

## Available Commands

Everything lives under the single `:Reposcope` command. The first argument is the
subcommand; remaining arguments are forwarded to it.

**UI Lifecycle & Prompt Configuration**

| Command                 | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `:Reposcope start`      | Opens the Reposcope UI                                              |
| `:Reposcope close`      | Closes all Reposcope windows and buffers                            |
| `:Reposcope prompt ...` | Dynamically sets new prompt fields (e.g. `prefix`, `keywords`, ...) |

**Repository List: Sorting & Filtering**

| Command                    | Description                                                            |
| -------------------------- | ---------------------------------------------------------------------- |
| `:Reposcope sort`          | Opens an interactive selection menu to choose a sort mode              |
| `:Reposcope filter {text}` | Filters the currently shown repositories by case-insensitive substring |
| `:Reposcope filter-prompt` | Opens a floating prompt window to input a filter string interactively  |
| `:Reposcope filter-clear`  | Clears any active filter and restores the full list of repositories    |

**Repository Maintenance**

| Command                     | Description                                                                       |
| --------------------------- | --------------------------------------------------------------------------------- |
| `:Reposcope update [dir]`   | Updates all cloned git repositories (`git fetch --all --prune` + `git pull --ff-only`) in `clone.std_dir` (or the given directory) |
| `:Reposcope status [dir]`   | Shows a git status overview (branch, ahead/behind, dirty) for every repo in `clone.std_dir` (or the given directory / a single repo) |

**Debugging, Stats & Metrics**

| Command                      | Description                                                              |
| ---------------------------- | ------------------------------------------------------------------------ |
| `:Reposcope toggle-dev`      | Toggles developer mode (enables debug logging, internal info, etc.)      |
| `:Reposcope print-dev`       | Prints whether developer mode is currently active                        |
| `:Reposcope skipped-readmes` | Shows number of skipped README fetches (debounced during fast scrolling) |
| `:Reposcope stats`           | Displays collected request stats and metrics                             |

> ℹ️ Run `:Reposcope` with no subcommand to print this list in Neovim, and use
> `<Tab>` completion to cycle through subcommands and their arguments.

---

#### `:Reposcope prompt {fields}`

Updates the active prompt fields dynamically. It closes and reopens the Reposcope UI to apply the new configuration — the specified fields will then appear in the prompt layout.

> 🧠 Prompt fields must be chosen from: `prefix`, `keywords`, `owner`, `language`, `topic`, `stars`.
> If no fields are given, it defaults to: `keywords`, `owner`, `language`.

Example:

```vim
:Reposcope prompt keywords topic         "prompt without prefix: 
:Reposcope prompt prefix topic stars     "prompt with prefix, topice and stars field
:Reposcope prompt                        "resets to default
```

---

#### `:Reposcope filter {text}`

Filters the current list of repositories using a case-insensitive substring
match.
The input is matched against the format: `owner/name: description`.

> If called without arguments, it resets the list to the original API result.

Examples:

```vim
:Reposcope filter typescript bun "matches any repository with strings
:Reposcope filter openai         "filter by organization or description
:Reposcope filter                "clears filter and restores all results
```

---

#### `:Reposcope filter-prompt`

Opens a small floating input field where you can type a filter query.
The behavior is identical to `:Reposcope filter`, but interactively.

Examples:

```vim
:Reposcope filter-prompt    "opens floating input to enter 'react', 'api', etc.
```

> Press `<Enter>` to confirm and filter; leave input empty to cancel.

---

#### `:Reposcope update [dir]`

Bulk-updates every cloned git repository found **directly inside** a directory.
For each repository it runs `git fetch --all --prune` followed by
`git pull --ff-only`, sequentially and asynchronously, so Neovim stays responsive.
Non-git subdirectories are skipped, errors are collected, and a summary is shown
when the run finishes.

If no argument is given, the configured clone directory (`clone.std_dir`) is used —
i.e. the place Reposcope clones repositories into. This makes the command the
natural continuation of the clone lifecycle: *discover → clone → update*.

> ℹ️ Only immediate subdirectories are scanned (non-recursive). The fast-forward-only
> pull never rewrites local history; diverged branches are reported as errors instead.

Examples:

```vim
:Reposcope update              "update all repos in clone.std_dir
:Reposcope update ~/projects   "update all repos inside ~/projects
```

---

#### `:Reposcope status [dir]`

Reads the git status of every cloned git repository found **directly inside** a
directory and prints a compact, aligned overview. For each repository it runs
`git status --porcelain=v2 --branch` asynchronously and distills the output into
the current branch, ahead/behind counts relative to the upstream, and how many
files are uncommitted (the *dirty* count) — summarized as one of the states
`clean`, `dirty`, `ahead`, `behind` or `diverged`.

If no argument is given, the configured clone directory (`clone.std_dir`) is used.
If the given path is **itself** a git repository, only that single repo is
reported; otherwise its immediate subdirectories are scanned. This is the
read-only counterpart to `:Reposcope update` — *discover → clone → status → update*.

> ℹ️ Only immediate subdirectories are scanned (non-recursive). The command never
> modifies anything; it only reads.

Example output:

```
REPOSITORY      BRANCH   AHEAD/BEH  STATE
reposcope.nvim  main     +0/-0      clean
my-fork         feature  +2/-1      dirty (3)
some-lib        main     +0/-4      behind
```

Examples:

```vim
:Reposcope status                 "status of all repos in clone.std_dir
:Reposcope status ~/projects      "status of all repos inside ~/projects
:Reposcope status ~/projects/foo  "status of the single repository foo
```
