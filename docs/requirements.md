# Requirements

## Required

| | |
| --- | --- |
| Neovim | **0.10+** |
| [lib.nvim](https://github.com/StefanBartl/lib.nvim) | the command layer, notifications and the progress indicator |
| [ui.nvim](https://github.com/StefanBartl/ui.nvim) | `ui.kit` backs the filter/sort prompts and the favorites/help/status views — `require("reposcope")`'s own top-level `require("reposcope.bindings.usrcmds")` reaches it before `setup()` ever runs, so it is required the moment this plugin loads, not just when those views open |
| `gh`, `curl` or `wget` | at least one of the three on `$PATH`; `request_tool` picks which |
| `git` | for cloning and for the status overview |

## Optional

Each detected at runtime and degrading to nothing when absent:

| | |
| --- | --- |
| `GITHUB_TOKEN` | Raises the GitHub API rate limit from 60 requests an hour to 5000. Not required, but the anonymous limit is easy to reach — see [authentication.md](authentication.md) |
| [hover.nvim](https://github.com/StefanBartl/hover.nvim) | `owner/repo` previews anywhere in any buffer |
| [images.nvim](https://github.com/StefanBartl/images.nvim) | The images a README references, drawn in the preview pane |

`:checkhealth reposcope` reports which request tools resolved, which one is
configured, whether a token is set, and how the image preview is wired.
