-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/http_client_spec.lua — the two client layers above the request tools.
--
-- `http_client` picks the tool, builds the provider-specific Authorization
-- header and wraps the call; `api_client` adds the provider's `Accept` header
-- and flattens the result. Both are driven here against stubbed request tools
-- (`gh`/`curl`/`wget` are replaced in `package.loaded` before the client is
-- required), so the assertions are about *which* request would have been made
-- and with which headers -- not about any process.

return function(H)
  local function tool_recorder()
    local calls = {}
    local function make(name)
      return {
        request = function(method, url, callback, headers, debug, context, uuid)
          calls[#calls + 1] = {
            tool = name,
            method = method,
            url = url,
            headers = headers,
            debug = debug,
            context = context,
            uuid = uuid,
          }
          callback("body-from-" .. name, nil)
        end,
      }
    end
    return calls, make("gh"), make("curl"), make("wget")
  end

  ---Runs `body` with the three request tools stubbed and `http_client` fresh.
  local function with_client(fn)
    local calls, gh, curl, wget = tool_recorder()
    H.with_stubs({
      ["reposcope.network.request_tools.gh"] = gh,
      ["reposcope.network.request_tools.curl"] = curl,
      ["reposcope.network.request_tools.wget"] = wget,
    }, { "reposcope.network.clients.http_client" }, function()
      local config = require("reposcope.config")
      local saved = {
        request_tool = config.options.request_tool,
        provider = config.options.provider,
        github_token = config.options.github_token,
        gitlab_token = config.options.gitlab_token,
        codeberg_token = config.options.codeberg_token,
      }
      local ok, err = pcall(fn, require("reposcope.network.clients.http_client"), calls, config)
      for k, v in pairs(saved) do
        config.options[k] = v
      end
      if not ok then error(err, 0) end
    end)
  end

  ---------------------------------------------------------------------------
  -- Nothing to request
  ---------------------------------------------------------------------------
  with_client(function(client, calls)
    local got = { "untouched" }
    client.request("GET", "", function(response, err) got = { response = response, err = err } end)
    H.eq(#calls, 0, "an empty URL never reaches a request tool")
    -- Silent on purpose: this is how the preview window is cleared, and an
    -- error message per cleared preview would be noise.
    H.eq(got.response, nil, "the callback still runs, with no response")
    H.eq(got.err, nil, "and deliberately no error either")

    client.request("GET", nil, function() end)
    H.eq(#calls, 0, "a nil URL is the same non-event")
  end)

  ---------------------------------------------------------------------------
  -- Tool selection
  ---------------------------------------------------------------------------
  with_client(function(client, calls, config)
    config.options.provider = "github"

    for _, tool in ipairs({ "gh", "curl", "wget" }) do
      config.options.request_tool = tool
      client.request("GET", "https://api.github.com/x", function() end)
      H.eq(calls[#calls].tool, tool, "the configured request tool is the one that runs: " .. tool)
    end

    -- An empty `request_tool` is not "no tool", it is curl -- get_option's
    -- documented fallback.
    config.options.request_tool = ""
    client.request("GET", "https://api.github.com/x", function() end)
    H.eq(calls[#calls].tool, "curl", "an empty request_tool falls back to curl")

    -- An unknown tool is a typed error through the callback, not a crash.
    config.options.request_tool = "httpie"
    local got
    client.request(
      "GET",
      "https://api.github.com/x",
      function(response, err) got = { response = response, err = err } end
    )
    H.eq(got.response, nil, "an unsupported tool produces no response")
    H.eq(got.err, "Unsupported request tool: httpie", "and names the tool it could not use")
  end)

  ---------------------------------------------------------------------------
  -- `gh` cannot talk to a non-GitHub host, so it is swapped for curl
  ---------------------------------------------------------------------------
  with_client(function(client, calls, config)
    config.options.request_tool = "gh"
    config.options.gitlab_token = "glpat-x"

    config.options.provider = "gitlab"
    client.request("GET", "https://gitlab.com/api/v4/projects", function() end)
    H.eq(calls[#calls].tool, "curl", "gh + gitlab falls back to curl")
    H.eq(calls[#calls].headers["PRIVATE-TOKEN"], "glpat-x", "and the fallback still authenticates")

    config.options.provider = "codeberg"
    client.request("GET", "https://codeberg.org/api/v1/x", function() end)
    H.eq(calls[#calls].tool, "curl", "gh + codeberg falls back too")

    config.options.provider = "github"
    client.request("GET", "https://api.github.com/x", function() end)
    H.eq(calls[#calls].tool, "gh", "gh + github is left alone")
  end)

  ---------------------------------------------------------------------------
  -- The Authorization header is provider-shaped
  ---------------------------------------------------------------------------
  with_client(function(client, calls, config)
    config.options.request_tool = "curl"
    config.options.github_token = "gho_a"
    config.options.gitlab_token = "glpat_b"
    config.options.codeberg_token = "cb_c"

    config.options.provider = "github"
    client.request("GET", "https://api.github.com/x", function() end)
    H.eq(calls[#calls].headers["Authorization"], "Bearer gho_a", "GitHub takes a Bearer token")

    config.options.provider = "gitlab"
    client.request("GET", "https://gitlab.com/x", function() end)
    H.eq(calls[#calls].headers["PRIVATE-TOKEN"], "glpat_b", "GitLab takes PRIVATE-TOKEN")
    H.eq(calls[#calls].headers["Authorization"], nil, "and no Authorization header at all")

    config.options.provider = "codeberg"
    client.request("GET", "https://codeberg.org/x", function() end)
    H.eq(calls[#calls].headers["Authorization"], "token cb_c", "Codeberg takes `token <value>`, not Bearer")

    -- An unknown provider is not a crash; it gets GitHub's shape, which is
    -- also what `TOKEN_OPTION`'s own fallback picks.
    config.options.provider = "sourcehut"
    client.request("GET", "https://x", function() end)
    H.eq(calls[#calls].headers["Authorization"], "Bearer gho_a", "an unknown provider falls back to the GitHub shape")

    -- gh authenticates through its own keyring/environment, so reposcope must
    -- not hand it a second, competing credential.
    config.options.provider = "github"
    config.options.request_tool = "gh"
    client.request("GET", "https://api.github.com/x", function() end)
    H.eq(calls[#calls].headers["Authorization"], nil, "gh gets no Authorization header -- it handles auth itself")

    -- No token configured: no header, rather than an empty one.
    config.options.request_tool = "curl"
    config.options.github_token = ""
    client.request("GET", "https://api.github.com/x", function() end)
    H.eq(calls[#calls].headers["Authorization"], nil, "an empty token produces no header")
  end)

  ---------------------------------------------------------------------------
  -- Caller headers, and what a UUID is for
  ---------------------------------------------------------------------------
  with_client(function(client, calls, config)
    config.options.request_tool = "curl"
    config.options.provider = "github"
    config.options.github_token = "gho_a"

    client.request("GET", "https://api.github.com/x", function() end, {
      ["Accept"] = "application/vnd.github+json",
      ["Authorization"] = "Bearer caller-supplied",
    }, false, "fetch_repositories")

    local sent = calls[#calls]
    H.eq(sent.headers["Accept"], "application/vnd.github+json", "a caller header is kept")
    H.eq(sent.headers["Authorization"], "Bearer gho_a", "but the configured token wins over a caller-supplied one")
    H.eq(sent.context, "fetch_repositories", "the metrics context is forwarded")
    H.ok(type(sent.uuid) == "string" and #sent.uuid > 0, "a request UUID is generated for the tool layer")

    local first = sent.uuid
    client.request("GET", "https://api.github.com/y", function() end)
    H.ok(calls[#calls].uuid ~= first, "and a fresh one per request")
  end)

  ---------------------------------------------------------------------------
  -- A request tool that raises is reported, not propagated
  ---------------------------------------------------------------------------
  do
    local exploding = {
      request = function() error("uv: EMFILE", 0) end,
    }
    H.with_stubs({
      ["reposcope.network.request_tools.gh"] = exploding,
      ["reposcope.network.request_tools.curl"] = exploding,
      ["reposcope.network.request_tools.wget"] = exploding,
    }, { "reposcope.network.clients.http_client" }, function()
      local config = require("reposcope.config")
      local saved_tool, saved_provider = config.options.request_tool, config.options.provider
      config.options.request_tool, config.options.provider = "curl", "github"

      local client = require("reposcope.network.clients.http_client")
      local got
      local ok = pcall(
        client.request,
        "GET",
        "https://api.github.com/x",
        function(response, err) got = { response = response, err = err } end
      )

      H.ok(ok, "a throwing request tool does not escape the client")
      H.eq(got.response, nil, "the callback gets no response")
      H.contains(got.err, "Request failed:", "and a NetworkError message")
      H.contains(got.err, "EMFILE", "carrying the original reason")

      config.options.request_tool, config.options.provider = saved_tool, saved_provider
    end)
  end

  ---------------------------------------------------------------------------
  -- api_client: the Accept header and the error flattening
  ---------------------------------------------------------------------------
  do
    local calls = {}
    local http_stub = {
      request = function(method, url, callback, headers, debug, context)
        calls[#calls + 1] = { method = method, url = url, headers = headers, debug = debug, context = context }
        calls[#calls].callback = callback
      end,
    }

    H.with_stubs(
      { ["reposcope.network.clients.http_client"] = http_stub },
      { "reposcope.network.clients.api_client" },
      function()
        local config = require("reposcope.config")
        local saved = config.options.provider
        local api = require("reposcope.network.clients.api_client")

        config.options.provider = "github"
        api.request("GET", "https://api.github.com/x", function() end)
        H.eq(calls[1].headers["Accept"], "application/vnd.github+json", "GitHub gets its own media type")
        H.eq(calls[1].context, "general", "an omitted context defaults to `general`")
        H.eq(calls[1].debug, nil, "api_client never turns on tool debugging by itself")

        config.options.provider = "gitlab"
        api.request("GET", "https://gitlab.com/x", function() end, nil, "fetch_repositories")
        H.eq(calls[2].headers["Accept"], "application/json", "every other provider gets plain JSON")
        H.eq(calls[2].context, "fetch_repositories", "and the caller's context is used")

        -- A caller that needs a different representation can say so.
        api.request("GET", "https://gitlab.com/x", function() end, { ["Accept"] = "text/plain" })
        H.eq(calls[3].headers["Accept"], "text/plain", "an explicit Accept from the caller wins")

        -- A non-table `headers` is ignored rather than crashing the merge.
        api.request("GET", "https://gitlab.com/x", function() end, "nonsense")
        H.eq(calls[4].headers["Accept"], "application/json", "a non-table headers argument is ignored")

        -- Result flattening: an error nils the response, a success nils the error.
        local got
        api.request("GET", "https://x", function(response, err) got = { response = response, err = err } end)
        calls[5].callback("ignored-body", "HTTP 403: rate limit exceeded")
        H.eq(got.response, nil, "an error drops whatever body came with it")
        H.eq(got.err, "HTTP 403: rate limit exceeded", "and passes the message on verbatim")

        calls[5].callback('{"items":[]}', nil)
        H.eq(got.response, '{"items":[]}', "a success passes the body through")
        H.eq(got.err, nil, "with no error")

        config.options.provider = saved
      end
    )
  end
end
