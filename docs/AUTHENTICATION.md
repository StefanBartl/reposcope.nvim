# Authentication

`reposcope.nvim` works out of the box — **no authentication is required** for basic usage.

However, if you want to use the `gh` CLI as your request backend, you **must** set a valid `GITHUB_TOKEN` manually:

```sh
export GITHUB_TOKEN=ghp_your_token_here
```

⚠️ **Important:** Logged-in `gh` sessions (via `gh auth login`) are **not** accessible to child processes started via `uv.spawn()` inside Neovim. Without an explicit `GITHUB_TOKEN`, `gh`-based requests will silently fail.

As an alternative, you can use `curl` or `wget` without authentication — but you’ll have lower API rate limits.

---

## Recommended: Set it explicitly in `setup({ ... })`

In some systems or plugin managers, Neovim **does not inherit** environment variables defined in `.zshenv`, `.profile`, or GUI launch contexts.

To avoid issues, we recommend passing the token directly during setup:

```lua
require("reposcope").setup({
  github_token = os.getenv("GITHUB_TOKEN") or "gh__example_token", -- Explicitly forward the env variable
  ...
})
```

This ensures the token is correctly passed to internal request handlers, regardless of how Neovim was started.

If you do not set a token, `curl` or `wget` will still work — but you may hit GitHub's anonymous rate limits.
