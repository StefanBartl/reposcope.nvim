-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/readme_fetcher_spec.lua — the three README fetchers.
--
-- Each provider offers two routes: the raw host (plain text) and the API
-- endpoint (JSON with a base64 `content` field). `api_client` is stubbed in
-- `package.loaded` before the fetcher is required, so the assertions are
-- about the URL that would have been requested and the decoding of whatever
-- comes back -- including the error shapes the manager above relies on.

return function(H)
  local PROVIDERS = {
    {
      name = "github",
      module = "reposcope.providers.github.readme.readme_fetcher",
      raw = "https://raw.githubusercontent.com/owner/repo/dev/README.md",
      api = "https://api.github.com/repos/owner/repo/readme?ref=dev",
    },
    {
      name = "gitlab",
      module = "reposcope.providers.gitlab.readme.readme_fetcher",
      raw = "https://gitlab.com/owner/repo/-/raw/dev/README.md",
      api = "https://gitlab.com/api/v4/projects/owner%2Frepo/repository/files/README.md?ref=dev",
    },
    {
      name = "codeberg",
      module = "reposcope.providers.codeberg.readme.readme_fetcher",
      raw = "https://codeberg.org/owner/repo/raw/branch/dev/README.md",
      api = "https://codeberg.org/api/v1/repos/owner/repo/contents/README.md?ref=dev",
    },
  }

  ---@param module string
  ---@param answer fun(request: table): nil|nil
  ---@param fn fun(fetcher: table, requests: table[]): nil
  local function with_fetcher(module, answer, fn)
    local requests = {}
    local api_stub = {
      request = function(method, url, callback, headers, context)
        local record = { method = method, url = url, headers = headers, context = context, callback = callback }
        requests[#requests + 1] = record
        if answer then answer(record) end
      end,
    }
    H.with_stubs(
      { ["reposcope.network.clients.api_client"] = api_stub },
      { module },
      function() fn(require(module), requests) end
    )
  end

  -- Same base64 encoder the providers' APIs use; built here rather than
  -- hardcoded so the fixture cannot drift from what is being decoded.
  local function b64(text) return vim.base64.encode(text) end

  for _, p in ipairs(PROVIDERS) do
    -------------------------------------------------------------------------
    -- The raw route
    -------------------------------------------------------------------------
    with_fetcher(p.module, function(req) req.callback("# Title\n\nbody", nil) end, function(fetcher, requests)
      local got
      fetcher.fetch_raw(
        "owner",
        "repo",
        "dev",
        function(success, content, err) got = { success = success, content = content, err = err } end
      )

      H.eq(#requests, 1, p.name .. ": one raw request")
      H.eq(requests[1].method, "GET", "a README fetch is a GET")
      H.eq(requests[1].url, p.raw, p.name .. ": the raw route is the one asked for")
      H.eq(requests[1].context, "readme_fetch_raw", "tagged as a raw README fetch for metrics")
      H.ok(got.success, "a raw body is a success")
      H.eq(got.content, "# Title\n\nbody", "and is handed back verbatim -- no decoding on this route")
    end)

    -- The raw route is plain text: whatever arrives is the README, even if it
    -- happens to look like JSON.
    with_fetcher(p.module, function(req) req.callback('{"content":"not decoded here"}', nil) end, function(fetcher)
      local got
      fetcher.fetch_raw(
        "owner",
        "repo",
        "dev",
        function(success, content) got = { success = success, content = content } end
      )
      H.eq(got.content, '{"content":"not decoded here"}', p.name .. ": the raw route never decodes")
    end)

    -- A transport error and an empty body are the same outcome for the caller.
    with_fetcher(p.module, function(req) req.callback(nil, "HTTP 404") end, function(fetcher)
      local got
      fetcher.fetch_raw(
        "owner",
        "repo",
        "dev",
        function(success, content, err) got = { success = success, content = content, err = err } end
      )
      H.falsy(got.success, p.name .. ": a transport error fails the raw fetch")
      H.eq(got.content, nil, "with no content")
      H.eq(got.err, "HTTP 404", "and the reason passed through")
    end)

    with_fetcher(p.module, function(req) req.callback(nil, nil) end, function(fetcher)
      local got
      fetcher.fetch_raw(
        "owner",
        "repo",
        "dev",
        function(success, _content, err) got = { success = success, err = err } end
      )
      H.falsy(got.success, p.name .. ": an empty response fails too")
      H.eq(got.err, "empty response", "and says so, rather than reporting a nil error")
    end)

    -------------------------------------------------------------------------
    -- The API route
    -------------------------------------------------------------------------
    with_fetcher(
      p.module,
      function(req) req.callback(vim.json.encode({ encoding = "base64", content = b64("# From the API") }), nil) end,
      function(fetcher, requests)
        local got
        fetcher.fetch_api(
          "owner",
          "repo",
          "dev",
          function(success, content, err) got = { success = success, content = content, err = err } end
        )

        H.eq(requests[1].url, p.api, p.name .. ": the API route is the one asked for")
        H.eq(requests[1].context, "readme_fetch_api", "tagged as an API README fetch")
        H.ok(got.success, "a decodable body is a success")
        H.eq(got.content, "# From the API", "and the base64 `content` field is decoded")
      end
    )

    -- Everything the API route can refuse.
    local api_rejections = {
      { body = "<html>502</html>", why = "an undecodable body" },
      { body = "{}", why = "a body with no `content` field" },
      { body = '{"message":"Not Found"}', why = "GitHub's 404 object" },
    }
    for _, case in ipairs(api_rejections) do
      with_fetcher(p.module, function(req) req.callback(case.body, nil) end, function(fetcher)
        local got
        fetcher.fetch_api(
          "owner",
          "repo",
          "dev",
          function(success, _content, err) got = { success = success, err = err } end
        )
        H.falsy(got.success, ("%s: %s is refused"):format(p.name, case.why))
        H.eq(got.err, "Invalid JSON or missing content", "with one message for the whole class")
      end)
    end

    with_fetcher(p.module, function(req) req.callback(nil, "HTTP 401") end, function(fetcher)
      local got
      fetcher.fetch_api(
        "owner",
        "repo",
        "dev",
        function(success, _content, err) got = { success = success, err = err } end
      )
      H.falsy(got.success, p.name .. ": a transport error fails the API fetch")
      H.eq(got.err, "HTTP 401", "and the reason travels")
    end)

    -------------------------------------------------------------------------
    -- A branch is optional; the URL builders default it
    -------------------------------------------------------------------------
    with_fetcher(p.module, nil, function(fetcher, requests)
      fetcher.fetch_raw("owner", "repo", nil, function() end)
      H.contains(requests[1].url, "main", p.name .. ": an omitted branch defaults to main")
    end)

    -------------------------------------------------------------------------
    -- An unusable repository identity never becomes a request
    -------------------------------------------------------------------------
    with_fetcher(p.module, nil, function(fetcher, requests)
      -- The URL builders `assert` on an empty owner/repo, which is the layer
      -- below this one; what matters here is that no request escapes.
      local ok = pcall(fetcher.fetch_raw, "", "repo", "dev", function() end)
      H.falsy(ok, p.name .. ": an empty owner is refused before any request")
      H.eq(#requests, 0, "and nothing was sent")
    end)
  end

  ---------------------------------------------------------------------------
  -- GitHub's README URL builder also accepts a full blob URL
  ---------------------------------------------------------------------------
  do
    local urls = require("reposcope.providers.github.readme.readme_urls")
    local from_blob = urls.get_urls("https://github.com/owner/repo/blob/dev/README.md")
    H.eq(
      from_blob.raw,
      "https://raw.githubusercontent.com/owner/repo/dev/README.md",
      "a blob URL is decomposed into owner/repo/branch"
    )
    H.eq(from_blob.api, "https://api.github.com/repos/owner/repo/readme?ref=dev", "for both routes")

    -- `/readme` rather than `/contents/README.md` on purpose: it resolves
    -- whatever spelling the repository actually uses.
    H.contains(urls.get_urls("o", "r").api, "/readme?ref=main", "the API route asks for the resolved README")
  end
end
