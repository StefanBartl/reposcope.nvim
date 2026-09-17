-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/repository_fetcher_spec.lua — the three search fetchers.
--
-- `reposcope.network.clients.api_client` is replaced in `package.loaded`
-- before each fetcher is required, so no request is ever made. Asserted: the
-- URL that would have been requested (including the encoded query), and every
-- branch of the response handling -- transport error, undecodable body, a
-- body of the wrong shape, an empty result set, and the success path
-- including each provider's normalization into the shared `Repository` shape.

return function(H)
  local cache = require("reposcope.cache.repository_cache")

  ---Drives one fetcher with a scripted API answer.
  ---@param module string
  ---@param answer fun(request: table): nil  called with the recorded request
  ---@param fn fun(fetcher: table, requests: table[], notes: string[]): nil
  local function with_fetcher(module, answer, fn)
    local requests = {}
    local notes = {}

    local api_stub = {
      request = function(method, url, callback, headers, context)
        local record = { method = method, url = url, headers = headers, context = context, callback = callback }
        requests[#requests + 1] = record
        if answer then answer(record) end
      end,
    }

    local debug_stub = {
      notify = function(msg) notes[#notes + 1] = msg end,
      is_dev_mode = function() return false end,
      debugf = function() end,
      options = { dev_mode = false },
    }

    H.with_stubs({
      ["reposcope.network.clients.api_client"] = api_stub,
      ["reposcope.utils.debug"] = debug_stub,
    }, { module }, function() fn(require(module), requests, notes) end)
  end

  local GITHUB = "reposcope.providers.github.repositories.repository_fetcher"
  local GITLAB = "reposcope.providers.gitlab.repositories.repository_fetcher"
  local CODEBERG = "reposcope.providers.codeberg.repositories.repository_fetcher"

  ---------------------------------------------------------------------------
  -- build_url: the query is percent-encoded into each provider's search route
  ---------------------------------------------------------------------------
  with_fetcher(GITHUB, nil, function(fetcher)
    H.eq(
      fetcher.build_url("user:me neovim plugin"),
      "https://api.github.com/search/repositories?q=user%3Ame%20neovim%20plugin",
      "GitHub's search route carries the whole query in `q`, percent-encoded"
    )
    H.eq(fetcher.build_url(""), "https://api.github.com/search/repositories?q=", "an empty query still builds a URL")
    H.eq(fetcher.build_url(nil), "https://api.github.com/search/repositories?q=", "as does a nil one")
  end)

  with_fetcher(GITLAB, nil, function(fetcher)
    local url = fetcher.build_url("neovim plugin")
    H.contains(url, "https://gitlab.com/api/v4/projects?search=", "GitLab searches /projects")
    H.contains(url, "neovim%20plugin", "with the encoded query")
    H.contains(url, "order_by=star_count", "ordered by stars")
    H.contains(url, "sort=desc", "descending")
  end)

  with_fetcher(
    CODEBERG,
    nil,
    function(fetcher)
      H.eq(
        fetcher.build_url("nvim"),
        "https://codeberg.org/api/v1/repos/search?q=nvim",
        "Codeberg uses Gitea's /repos/search route"
      )
    end
  )

  ---------------------------------------------------------------------------
  -- An empty query is refused before any request is made
  ---------------------------------------------------------------------------
  for _, module in ipairs({ GITHUB, GITLAB, CODEBERG }) do
    with_fetcher(module, nil, function(fetcher, requests, notes)
      local succeeded, failed = false, false
      fetcher.fetch_repositories("", function() succeeded = true end, function() failed = true end)
      H.eq(#requests, 0, "an empty query never reaches the network: " .. module)
      H.falsy(succeeded, "and does not report success")
      H.ok(failed, "it reports failure")
      H.contains(notes[1], "Search query is empty", "and says why")
    end)
  end

  ---------------------------------------------------------------------------
  -- The request that would have been made
  ---------------------------------------------------------------------------
  with_fetcher(GITHUB, nil, function(fetcher, requests)
    fetcher.fetch_repositories("nvim", function() end, function() end)
    H.eq(#requests, 1, "exactly one request")
    H.eq(requests[1].method, "GET", "a search is a GET")
    H.eq(requests[1].url, "https://api.github.com/search/repositories?q=nvim", "against the built URL")
    H.eq(requests[1].headers, nil, "with no extra headers -- api_client owns Accept, http_client owns auth")
    H.eq(requests[1].context, "fetch_repositories", "tagged for metrics")
  end)

  ---------------------------------------------------------------------------
  -- Transport error: the cache is emptied, not left stale
  ---------------------------------------------------------------------------
  for _, module in ipairs({ GITHUB, GITLAB, CODEBERG }) do
    with_fetcher(
      module,
      function(req) req.callback(nil, "HTTP 403: rate limit exceeded") end,
      function(fetcher, _, notes)
        cache.set({ total_count = 1, items = { { name = "stale", owner = { login = "old" }, description = "d" } } })
        H.eq(#cache.get().items, 1, "the cache starts out populated: " .. module)

        local failed = false
        fetcher.fetch_repositories(
          "nvim",
          function() error("success must not be reported") end,
          function() failed = true end
        )

        H.ok(failed, "a transport error reports failure")
        H.eq(#cache.get().items, 0, "and clears the previous result rather than leaving it on screen")
        H.contains(table.concat(notes, "\n"), "rate limit exceeded", "the reason is surfaced")
      end
    )
  end

  ---------------------------------------------------------------------------
  -- Undecodable and wrongly-shaped bodies
  ---------------------------------------------------------------------------
  local malformed = {
    [GITHUB] = { "<html>502 Bad Gateway</html>", "{}", '{"message":"Not Found"}', "" },
    [GITLAB] = { "<html>502 Bad Gateway</html>", "12", '"a string"', "null" },
    [CODEBERG] = { "<html>502 Bad Gateway</html>", "{}", '{"ok":true}', "" },
  }
  for module, bodies in pairs(malformed) do
    for _, body in ipairs(bodies) do
      with_fetcher(module, function(req) req.callback(body, nil) end, function(fetcher)
        cache.set({ total_count = 1, items = { { name = "stale", owner = { login = "old" }, description = "d" } } })
        local failed = false
        fetcher.fetch_repositories(
          "nvim",
          function() error("success must not be reported") end,
          function() failed = true end
        )
        H.ok(failed, ("%s rejects %s"):format(module, body))
        H.eq(#cache.get().items, 0, "and empties the cache")
      end)
    end
  end

  ---------------------------------------------------------------------------
  -- A body of `null` is valid JSON, and all three fetchers reject it cleanly
  ---------------------------------------------------------------------------
  -- `vim.json.decode("null")` succeeds and returns `vim.NIL`, a userdata
  -- value -- which is *truthy* in Lua, so a bare `not parsed` guard misses
  -- it and a later `parsed.items`/`.data` indexes the userdata directly.
  -- All three guards now check `type(parsed) ~= "table"` instead (the same
  -- class of defect `utils.core.ensure_string`'s `vim.NIL` check guards
  -- against), so a `null` body fails cleanly through `on_failure` like any
  -- other malformed response, on every provider.
  for _, module in ipairs({ GITHUB, CODEBERG, GITLAB }) do
    with_fetcher(module, function(req) req.callback("null", nil) end, function(fetcher)
      local failed = false
      local ok = pcall(
        fetcher.fetch_repositories,
        "nvim",
        function() error("success must not be reported") end,
        function() failed = true end
      )
      H.ok(ok, "a `null` body fails cleanly instead of raising: " .. module)
      H.ok(failed, "and on_failure is reached: " .. module)
    end)
  end

  ---------------------------------------------------------------------------
  -- An empty result set is a success, not a failure
  ---------------------------------------------------------------------------
  local empty_bodies = {
    [GITHUB] = '{"total_count":0,"items":[]}',
    [GITLAB] = "[]",
    [CODEBERG] = '{"ok":true,"data":[]}',
  }
  for module, body in pairs(empty_bodies) do
    with_fetcher(module, function(req) req.callback(body, nil) end, function(fetcher)
      cache.set({ total_count = 3, items = { { name = "stale", owner = { login = "old" }, description = "d" } } })
      local succeeded = false
      fetcher.fetch_repositories(
        "nothing-matches",
        function() succeeded = true end,
        function() error("an empty result set is not a failure") end
      )
      H.drain()
      H.ok(succeeded, "zero results still reports success: " .. module)
      H.eq(#cache.get().items, 0, "and the cache reflects the empty result")
      H.eq(cache.get().total_count, 0, "including the count")
    end)
  end

  ---------------------------------------------------------------------------
  -- GitHub: the response shape is used as-is
  ---------------------------------------------------------------------------
  with_fetcher(
    GITHUB,
    function(req)
      req.callback(
        vim.json.encode({
          total_count = 2,
          items = {
            {
              name = "telescope.nvim",
              owner = { login = "nvim-telescope" },
              description = "Find files",
              html_url = "https://github.com/nvim-telescope/telescope.nvim",
              default_branch = "master",
              stargazers_count = 15000,
              updated_at = "2026-01-01T00:00:00Z",
            },
            { name = "fzf-lua", owner = { login = "ibhagwan" }, description = "Fuzzy", stargazers_count = 2000 },
          },
        }),
        nil
      )
    end,
    function(fetcher, _, notes)
      local succeeded = false
      fetcher.fetch_repositories("nvim", function() succeeded = true end, function() error("must not fail") end)
      H.drain()
      H.ok(succeeded, "a well-formed response reports success")

      local items = cache.get().items
      H.eq(#items, 2, "both repositories are cached")
      H.eq(items[1].name, "telescope.nvim", "in order")
      H.eq(items[1].owner.login, "nvim-telescope", "with their owner")
      H.eq(cache.get().total_count, 2, "and the total count comes from the response")

      -- The original relevance order is snapshotted, so `:Reposcope sort
      -- relevance` has something to restore.
      H.ok(cache.relevance_result, "the untouched response is kept for relevance sorting")
      H.eq(#cache.relevance_result.items, 2, "with all items")

      -- BUG: the "N repositories received" line reads
      --   "[reposcope] " .. #parsed.items or 0 .. " repositories received..."
      -- and `..` binds tighter than `or`, so the whole message collapses to the
      -- left operand: the count is printed, the sentence that explains it never
      -- is. Cosmetic, dev-mode only -- but it is also the only place in the
      -- three fetchers where the count is reported at all, and the GitLab and
      -- Codeberg fetchers next to it get the same sentence right.
      local last = notes[#notes]
      H.eq(last, "[reposcope] 2", "BUG: the success message is truncated to the bare count")
      H.excludes(last, "repositories received", "BUG: the explaining half never reaches the user")
    end
  )

  ---------------------------------------------------------------------------
  -- GitLab: a flat array of projects, normalized into the shared shape
  ---------------------------------------------------------------------------
  with_fetcher(
    GITLAB,
    function(req)
      req.callback(
        vim.json.encode({
          {
            path = "gitlab-runner",
            description = "Runs jobs",
            http_url_to_repo = "https://gitlab.com/gitlab-org/gitlab-runner.git",
            web_url = "https://gitlab.com/gitlab-org/gitlab-runner",
            namespace = { path = "gitlab-org" },
            default_branch = "main",
            star_count = 3000,
            last_activity_at = "2026-02-02T00:00:00Z",
          },
          { path = "bare", web_url = "https://gitlab.com/someone/bare" },
        }),
        nil
      )
    end,
    function(fetcher, _, notes)
      fetcher.fetch_repositories("runner", function() end, function() error("must not fail") end)
      H.drain()

      local items = cache.get().items
      H.eq(#items, 2, "both projects are normalized")
      H.eq(items[1].name, "gitlab-runner", "GitLab's `path` becomes `name`")
      H.eq(items[1].owner.login, "gitlab-org", "the namespace becomes the owner login")
      H.eq(
        items[1].html_url,
        "https://gitlab.com/gitlab-org/gitlab-runner.git",
        "the .git clone URL wins over web_url, so clone_command can parse owner/repo back out"
      )
      H.eq(items[1].stargazers_count, 3000, "star_count becomes stargazers_count")
      H.eq(items[1].updated_at, "2026-02-02T00:00:00Z", "last_activity_at stands in for updated_at")

      H.eq(items[2].html_url, "https://gitlab.com/someone/bare", "without a clone URL, web_url is used")
      H.eq(items[2].owner.login, "Unknown", "a project without a namespace still renders -- the cache substitutes")
      H.eq(items[2].description, "No description", "and a missing description too")

      -- GitLab's search response has no total_count; the fetcher supplies the
      -- number of items actually returned.
      H.eq(cache.get().total_count, 2, "total_count is approximated from the item count")
      H.contains(notes[#notes], "2 repositories received from GitLab", "and the count is reported in full")
    end
  )

  ---------------------------------------------------------------------------
  -- Codeberg: Gitea wraps results in `data`
  ---------------------------------------------------------------------------
  with_fetcher(
    CODEBERG,
    function(req)
      req.callback(
        vim.json.encode({
          ok = true,
          data = {
            {
              name = "forgejo",
              description = "Self-hosted",
              clone_url = "https://codeberg.org/forgejo/forgejo.git",
              html_url = "https://codeberg.org/forgejo/forgejo",
              owner = { login = "forgejo" },
              default_branch = "forgejo",
              stars_count = 1200,
              updated_at = "2026-03-03T00:00:00Z",
            },
            { name = "orphan", html_url = "https://codeberg.org/x/orphan" },
          },
        }),
        nil
      )
    end,
    function(fetcher, _, notes)
      fetcher.fetch_repositories("forgejo", function() end, function() error("must not fail") end)
      H.drain()

      local items = cache.get().items
      H.eq(#items, 2, "both repositories are normalized")
      H.eq(items[1].name, "forgejo", "name comes through")
      H.eq(items[1].owner.login, "forgejo", "as does the owner")
      H.eq(items[1].html_url, "https://codeberg.org/forgejo/forgejo.git", "clone_url wins over html_url")
      H.eq(items[1].stargazers_count, 1200, "stars_count becomes stargazers_count")
      H.eq(items[2].html_url, "https://codeberg.org/x/orphan", "without a clone URL, html_url is used")
      H.contains(notes[#notes], "2 repositories received from Codeberg", "the count is reported in full")
    end
  )

  cache.clear()
end
