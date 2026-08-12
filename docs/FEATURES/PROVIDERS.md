# Providers

Everything about *where* repositories and READMEs come from, and how a
found repository ends up as a local clone.

## GitHub repository search (field-based)

Structured prompt fields (`keywords`, `owner`, `language`, `topic`,
`stars`, ...) are translated into a real GitHub search query string, not a
single free-text box.

- **Module:** `providers/github/query_builder.lua` (`M.build`),
  `providers/github/repositories/repository_fetcher.lua`,
  `providers/github/repositories/repository_manager.lua`
- **Config:** `provider = "github"` (default), `results_limit`
- **Usercmds:** `:Reposcope prompt {fields}` to change which fields are
  shown (see [COMMANDS.md](../COMMANDS.md))

## GitLab provider support

Same search/README/clone lifecycle as GitHub, routed through GitLab's own
API and query grammar.

- **Module:** `providers/gitlab/query_builder.lua`,
  `providers/gitlab/repositories/repository_fetcher.lua`,
  `providers/gitlab/repositories/repository_manager.lua`,
  `providers/gitlab/entrypoint.lua`
- **Config:** `provider = "gitlab"`, `gitlab_token`

## Codeberg provider support

Same search/README/clone lifecycle again, routed through Codeberg's
Gitea-based API.

- **Module:** `providers/codeberg/query_builder.lua`,
  `providers/codeberg/repositories/repository_fetcher.lua`,
  `providers/codeberg/repositories/repository_manager.lua`,
  `providers/codeberg/entrypoint.lua`
- **Config:** `provider = "codeberg"`, `codeberg_token`

## `:Reposcope providers` – list available/active providers

Prints every registered provider (`github`, `gitlab`, `codeberg`) with the
currently active one marked `*`.

- **Module:** `bindings/usrcmds.lua` (`subcommands.providers`),
  `controllers/provider_controller.lua` (`get_active_provider`,
  `get_registered_providers`)
- **Usercmds:** `:Reposcope providers` (see
  [BINDINGS.md](../BINDINGS.md#user-commands))
- **Docs:** [`docs/COMMANDS.md`](../COMMANDS.md) "`:Reposcope providers`"
  section.

## GitHub README rendering (raw + API fallback)

Fetches a repository's README as raw Markdown first, falling back to the
provider's content API when the raw fetch fails (private repos, missing
`README.md` at the expected path, rate limiting, ...).

- **Module:** `providers/github/readme/readme_fetcher.lua`,
  `providers/github/readme/readme_manager.lua`,
  `providers/github/readme/readme_urls.lua`

## Clone repo with tool of choice (`git`, `gh`, `curl`, `wget`)

Clones the selected repository using whichever tool is configured or
available — `git clone` by default, or `gh repo clone`/`curl`/`wget` (the
latter two pulling a `.zip` archive instead) when set explicitly.

- **Module:** `providers/github/clone/clone_manager.lua`,
  `providers/github/clone/clone_command.lua`,
  `controllers/clone_executor.lua`, `controllers/clone_info.lua`
  (equivalents under `providers/gitlab/clone/` and `providers/codeberg/clone/`)
- **Config:** `clone.std_dir` (target directory), `clone.type` (`""`
  default → `git`, or `curl`/`wget`/`gh`), `preferred_requesters`,
  `request_tool`
- **Keymaps:** `<C-c>` in the prompt (see
  [BINDINGS.md](../BINDINGS.md#keymaps))
