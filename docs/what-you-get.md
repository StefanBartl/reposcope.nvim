# What you get with the defaults

| Command | Does |
| --- | --- |
| `:Reposcope start` | Search, preview and clone across GitHub, GitLab and Codeberg, with README caching and precaching |
| `:Reposcope dashboard [dir]` | The git dashboard across a folder of clones; push, pull or fetch a row inline, `m` to mark a set, or `gp` / `gP` / `gf` / `gu` for the whole folder |
| `:Reposcope update [dir]` | Bulk `git fetch` plus a fast-forward-only `pull` across a folder |
| `:Reposcope filter` / `filter-prompt` / `sort` | Narrow and reorder the current results |
| `:Reposcope favorites` | Saved repositories, including a README snapshot for offline viewing |
| `:Reposcope session` | The last search, filter and sort mode, across restarts |
| `:Reposcope queries` | Your most-frequent searches |
| `:Reposcope providers` / `stats` / `toggle-dev` | The provider list, request metrics, and the developer tooling |
| `owner/repo` under the cursor | With [hover.nvim](https://github.com/StefanBartl/hover.nvim) installed, previews that repository's cached README — anywhere, not just in the picker |

The full subcommand reference is [commands.md](commands.md), and
every key is [BINDINGS.md](BINDINGS.md).
