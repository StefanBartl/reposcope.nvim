# Commands

All functionality is exposed through a single `:Reposcope <subcommand> [args]`
command, built via [`lib.nvim.bindings.usercmd.composer`](https://github.com/StefanBartl/lib.nvim).
Run `:Reposcope` without arguments to print the list of available
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
  - [:Reposcope providers](#reposcope-providers)
  - [:Reposcope session save|restore|clear](#reposcope-session-saverestoreclear)
  - [:Reposcope favorites list|clear](#reposcope-favorites-listclear)
  - [:Reposcope queries list|clear](#reposcope-queries-listclear)

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
| `<C-u>`/`<C-d>` | n/i | Scroll the README preview, staying in the prompt |
| `<C-p>`       | n/i  | Draw the README's image over the preview (needs images.nvim) |
| `<C-f>`       | n/i  | Toggle favorite for the selected repository |
| `?`           | n    | Show the keymap cheatsheet            |

All prompt keymaps above are configurable and disableable via `prompt_keymaps`,
and are picked up automatically by [which-key](https://github.com/folke/which-key.nvim)
if installed. See [BINDINGS.md](BINDINGS.md) for the full, authoritative
list of keymaps, user commands, and autocommands.

---

## Available Commands

Everything lives under the single `:Reposcope` command. The first argument is the
subcommand; remaining arguments are forwarded to it.

### UI Lifecycle & Prompt Configuration

| Command                 | Description                                                         |
| ----------------------- | ------------------------------------------------------------------- |
| `:Reposcope start`      | Opens the Reposcope UI                                              |
| `:Reposcope close`      | Closes all Reposcope windows and buffers                            |
| `:Reposcope prompt ...` | Dynamically sets new prompt fields (e.g. `prefix`, `keywords`, ...) |

### Repository List: Sorting & Filtering

| Command                    | Description                                                            |
| -------------------------- | ---------------------------------------------------------------------- |
| `:Reposcope sort`          | Opens an interactive selection menu to choose a sort mode              |
| `:Reposcope filter {text}` | Filters the currently shown repositories by case-insensitive substring |
| `:Reposcope filter-prompt` | Opens a floating prompt window to input a filter string interactively  |
| `:Reposcope filter-clear`  | Clears any active filter and restores the full list of repositories    |

### Repository Maintenance

| Command                     | Description                                                                       |
| --------------------------- | --------------------------------------------------------------------------------- |

### Providers

| Command                | Description                                                    |
| ----------------------- | --------------------------------------------------------------- |
| `:Reposcope providers`  | Lists available providers (`github`, `gitlab`, `codeberg`) and marks the active one |

### Session

| Command                                    | Description                                                    |
| ------------------------------------------- | --------------------------------------------------------------- |
| `:Reposcope session save`                  | Saves the current provider, prompt input, last query, filter, and sort mode |
| `:Reposcope session restore`               | Restores the saved session and re-runs the last search          |
| `:Reposcope session clear`                 | Deletes the saved session file, if any                          |

### Favorites & Query History

| Command                          | Description                                                    |
| ---------------------------------- | --------------------------------------------------------------- |
| `:Reposcope favorites` / `favorites list` | Lists favorited repositories in a popup                 |
| `:Reposcope favorites clear`       | Removes all favorites                                            |
| `:Reposcope queries` / `queries list`     | Prints your top-10 most-frequent search queries          |
| `:Reposcope queries clear`         | Clears the recorded query stats                                  |

### Debugging, Stats & Metrics

| Command                      | Description                                                              |
| ---------------------------- | ------------------------------------------------------------------------ |
| `:Reposcope messages [clear]` | Opens reposcope's message history in a buffer (yankable), or forgets it |
| `:Reposcope toggle-dev`      | Toggles developer mode (enables debug logging, internal info, etc.)      |
| `:Reposcope print-dev`       | Prints whether developer mode is currently active                        |
| `:Reposcope skipped-readmes` | Shows number of skipped README fetches (debounced during fast scrolling) |
| `:Reposcope stats`           | Displays collected request stats and metrics                             |

> Run `:Reposcope` with no subcommand to print this list in Neovim, and use
> `<Tab>` completion to cycle through subcommands and their arguments.

---

#### `:Reposcope prompt {fields}`

Updates the active prompt fields dynamically. It closes and reopens the Reposcope UI to apply the new configuration — the specified fields will then appear in the prompt layout.

> Prompt fields must be chosen from: `prefix`, `keywords`, `owner`, `language`, `topic`, `stars`.
> If no fields are given, it defaults to: `keywords`, `owner`, `language`.

Example:

```vim
:Reposcope prompt keywords topic         "prompt without prefix field
:Reposcope prompt prefix topic stars     "prompt with prefix, topic and stars field
:Reposcope prompt                        "resets to default
```

---

#### `:Reposcope filter {text}`

Filters the current list of repositories using a case-insensitive substring
match.
The input is matched against the format: `owner/name: description`.

> If called without arguments, it resets the list to the original API result.

**`<Tab>` completes against the list actually on screen**: the
repository names and owners in the current result set, prefix-matched. Those
are the only candidates that can match anything, since the filter is a
substring over `owner/name: description` — guessing at one and getting an
empty list back was the whole friction. Owners are offered alongside names
because filtering to one owner is the common case and the owner is not the
leading token of every entry.

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

#### `:Reposcope providers`

Lists every registered provider (`github`, `gitlab`, `codeberg`) and marks
the currently active one (set via the `provider` config option) with `*`.

Example output:

```
  codeberg
  github
* gitlab
```

---

#### `:Reposcope session save|restore|clear`

Persists (or restores, or clears) the last search session: the active
provider, the visible prompt fields and their typed-in text, the last built
search query, the active filter text, and the current sort mode. The session
is written as a single JSON file under the plugin's cache directory and
survives Neovim restarts. Nothing is saved automatically — you decide when a
session is worth keeping.

- `save` — writes the current session, overwriting any previous one.
- `restore` — restores the saved provider/prompt/input, then re-runs the last
  search; once results arrive, the saved filter and sort mode are re-applied.
- `clear` — deletes the saved session file, if one exists.

Examples:

```vim
:Reposcope session save     "remember the current search, filter and sort
:Reposcope session restore  "bring back the last saved search
:Reposcope session clear    "delete the saved session
```

---

#### `:Reposcope favorites list|clear`

Lists favorited repositories in a scrollable popup, or clears all of them.
A favorite is toggled while browsing with the `toggle_favorite` prompt
keymap (default `<C-f>`) — there's no separate "add favorite" command.
Toggling snapshots the repository's metadata (owner, name, description,
URL, stars) *and* its README content if already cached, so the favorite is
self-contained: viewing it later needs no live re-fetch. Persisted as a
single JSON file under the plugin's cache directory; survives restarts.

> If you have any favorites saved, `:Reposcope start` shows them
> immediately (list populated, first entry's preview pre-warmed from its
> README snapshot) instead of starting from an empty prompt.

- `favorites` / `favorites list` — opens the popup (`q`/`<Esc>` to close).
- `favorites clear` — removes all favorites.

Examples:

```vim
:Reposcope favorites        "same as 'favorites list'
:Reposcope favorites clear  "remove all favorites
```

---

#### `:Reposcope queries list|clear`

Every real search (pressing `<CR>` in the prompt) increments a persisted
run-count for the exact query that was built. `queries list` prints the
top 10, most-frequent first; `queries clear` resets the counts. Recorded
automatically — no opt-in needed, since it's local-only and never leaves
the plugin's cache directory.

Examples:

```vim
:Reposcope queries        "same as 'queries list'
:Reposcope queries clear  "reset the recorded query stats
```
