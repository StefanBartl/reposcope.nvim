-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/metrics_spec.lua — request bookkeeping: the session counters, the
-- JSON request log behind `:Reposcope stats`, the rate-limit probe, and the
-- two pure aggregations in `utils.stats` that read the same file.
--
-- `reposcope.config` is replaced wholesale before `metrics` is required: the
-- log path is a module-level constant computed from `stdpath("cache")`, so
-- overriding an option would not move it -- and a test that wrote into the
-- user's real cache directory would be a defect of its own.

return function(H)
  local dir, cleanup = H.fixture("metrics")
  local log_path = dir .. "/request_log.json"

  ---@param opts table  { log_max?: integer, metrics?: boolean, token?: string }
  ---@param fn fun(metrics: table, notes: string[], config_stub: table): nil
  local function with_metrics(opts, fn)
    local notes = {}
    local config_stub = {
      options = {
        metrics = opts.metrics ~= false,
        log_max = opts.log_max or 1000,
        github_token = opts.token or "",
      },
      get_option = function(key)
        if key ~= "logfile_path" then return nil end
        -- `log_path = false` models "the plugin has no usable log path".
        if opts.log_path == false then return nil end
        return opts.log_path or log_path
      end,
    }

    H.with_stubs({
      ["reposcope.config"] = config_stub,
      ["reposcope.utils.debug"] = {
        notify = function(msg) notes[#notes + 1] = msg end,
        is_dev_mode = function() return false end,
        debugf = function() end,
        options = { dev_mode = false },
      },
    }, { "reposcope.utils.metrics" }, function() fn(require("reposcope.utils.metrics"), notes, config_stub) end)
  end

  local ok, err = pcall(function()
    -------------------------------------------------------------------------
    -- Session counters
    -------------------------------------------------------------------------
    -- Its own log file: these calls also write log entries, and a scheduled
    -- write landing after the next block deleted the shared file would make
    -- that block's counts non-deterministic.
    with_metrics({ log_path = dir .. "/counters.json" }, function(metrics)
      local start = metrics.get_session_requests()
      H.eq(start.successful, 0, "a fresh session has recorded no successes")
      H.eq(start.failed, 0, "no failures")
      H.eq(start.cache_hitted, 0, "no cache hits")
      H.eq(start.fcache_hitted, 0, "and no filecache hits")

      metrics.increase_success("u1", "q", "curl", "ctx", 12.5, 200, "https://x")
      metrics.increase_success("u2", "q", "curl", "ctx", 12.5, 200, "https://x")
      metrics.increase_failed("u3", "q", "gh", "ctx", 1, 404, "not found", "https://x")
      metrics.increase_cache_hit("u4", "q", "ram", "readme_manager", "https://x")
      metrics.increase_fcache_hit("u5", "q", "file", "readme_manager", "https://x")

      local after = metrics.get_session_requests()
      H.eq(after.successful, 2, "successes are counted")
      H.eq(after.failed, 1, "failures separately")
      H.eq(after.cache_hitted, 1, "RAM hits separately again")
      H.eq(after.fcache_hitted, 1, "and disk hits on their own")

      -- The returned table is a snapshot, not the live counter.
      after.successful = 99
      H.eq(metrics.get_session_requests().successful, 2, "the snapshot is a copy, not the live counters")
    end)

    -------------------------------------------------------------------------
    -- record_metrics is the on/off switch every call site checks first
    -------------------------------------------------------------------------
    with_metrics({ metrics = false, log_path = dir .. "/counters.json" }, function(metrics, _, config_stub)
      H.falsy(metrics.record_metrics(), "recording is off by default")
      H.ok(metrics.toggle_record_metrics(), "toggling turns it on")
      H.ok(config_stub.options.metrics, "which is stored in the configuration, not a module-local")
      H.falsy(metrics.toggle_record_metrics(), "and toggling again turns it off")
      H.ok(metrics.set_record_metrics(true), "it can also be set outright")
      H.ok(metrics.record_metrics(), "and reads back")
    end)

    -------------------------------------------------------------------------
    -- The request log on disk
    -------------------------------------------------------------------------
    vim.fn.delete(log_path)
    with_metrics({}, function(metrics)
      metrics.increase_success("uuid-a", "nvim", "curl", "fetch_repositories", 42.0, 200, "https://api/x")
      -- The write is scheduled: logging must never happen on the hot path of
      -- a response callback.
      vim.wait(500, function() return vim.fn.filereadable(log_path) == 1 end)

      local logs = vim.json.decode(H.read(log_path))
      local entry = logs["uuid-a:api_success"]
      H.ok(
        entry,
        "the entry is keyed by UUID and type, so a retry of the same request overwrites rather than duplicates"
      )
      H.eq(entry.type, "api_success", "carrying its type")
      H.eq(entry.query, "nvim", "the query")
      H.eq(entry.source, "curl", "the tool that made the request")
      H.eq(entry.context, "fetch_repositories", "the context")
      H.eq(entry.duration_ms, 42.0, "the measured duration")
      H.eq(entry.status_code, 200, "the status")
      H.eq(entry.url, "https://api/x", "and the URL verbatim, not one derived from the query")
      H.contains(entry.timestamp, "T", "with an ISO-8601 UTC timestamp")
      H.contains(entry.timestamp, "Z", "explicitly in UTC")

      metrics.increase_failed("uuid-b", "nvim", "gh", "fetch_repositories", 7, 404, "not found", "https://api/y")
      vim.wait(500, function() return H.read(log_path):find("uuid-b", 1, true) ~= nil end)
      logs = vim.json.decode(H.read(log_path))
      H.eq(logs["uuid-b:api_failed"].error_message, "not found", "a failure records the error message")
      H.eq(vim.tbl_count(logs), 2, "and the log accumulates rather than being replaced")
    end)

    -- An invalid UUID is refused outright: the key is built from it.
    with_metrics({ log_path = dir .. "/counters.json" }, function(metrics, notes)
      metrics.increase_success(42, "q", "curl", "ctx", 1, 200)
      vim.wait(100)
      H.contains(table.concat(notes, "\n"), "Invalid UUID type", "a non-string UUID is reported and not logged")
    end)

    -- The log is bounded: over `log_max`, the oldest entry is evicted.
    vim.fn.delete(log_path)
    with_metrics({ log_max = 3 }, function(metrics)
      for i = 1, 6 do
        metrics.increase_success("uuid-" .. i, "q", "curl", "ctx", 1, 200)
        vim.wait(
          200,
          function() return vim.fn.filereadable(log_path) == 1 and H.read(log_path):find("uuid-" .. i, 1, true) ~= nil end
        )
      end
      local count = vim.tbl_count(vim.json.decode(H.read(log_path)))
      H.ok(count <= 4, "the log stays bounded by log_max rather than growing forever")
      H.ok(count >= 3, "while still keeping roughly that many entries")
    end)

    -- A corrupt log is started over rather than crashing the next request --
    -- but the corrupt bytes are backed up first (ERR-11): the load-modify-
    -- save cycle below would otherwise silently overwrite them with a
    -- single-entry log and no trace they ever existed.
    local backup_path = log_path .. ".corrupt"
    vim.fn.delete(backup_path)
    vim.fn.writefile({ "{not json" }, log_path)
    with_metrics({}, function(metrics, notes)
      metrics.increase_success("after-corruption", "q", "curl", "ctx", 1, 200)
      vim.wait(500, function() return H.read(log_path):find("after-corruption", 1, true) ~= nil end)
      H.contains(table.concat(notes, "\n"), "is not valid JSON", "the corruption is reported")
      H.contains(table.concat(notes, "\n"), backup_path, "naming where the original was kept")
      H.ok(
        vim.json.decode(H.read(log_path))["after-corruption:api_success"],
        "and the new entry is written to a fresh log"
      )
      H.eq(vim.fn.filereadable(backup_path), 1, "the corrupt original is preserved alongside the fresh log")
      H.contains(H.read(backup_path), "{not json", "holding the original, unrecoverable-otherwise bytes")
    end)
    vim.fn.delete(backup_path)

    -------------------------------------------------------------------------
    -- Totals read back from the log
    -------------------------------------------------------------------------
    vim.fn.delete(log_path)
    with_metrics({}, function(metrics)
      local zero = metrics.get_total_requests()
      H.eq(zero.successful, 0, "a missing log file totals zero, silently")
      H.eq(zero.failed, 0, "across every counter")

      vim.fn.writefile({}, log_path)
      H.eq(metrics.get_total_requests().successful, 0, "an empty log file totals zero too")

      vim.fn.writefile({
        vim.json.encode({
          ["a:api_success"] = { type = "api_success", duration_ms = 10, query = "alpha" },
          ["b:api_success"] = { type = "api_success", duration_ms = 30, query = "alpha" },
          ["c:api_failed"] = { type = "api_failed", query = "beta" },
          ["d:cache_hit"] = { type = "cache_hit", query = "alpha" },
          ["e:filecache_hit"] = { type = "filecache_hit", query = "gamma" },
          ["f:something_else"] = { type = "unrecognised" },
        }),
      }, log_path)

      local totals = metrics.get_total_requests()
      H.eq(totals.successful, 2, "successes are totalled by type")
      H.eq(totals.failed, 1, "failures too")
      H.eq(totals.cache_hitted, 1, "RAM hits")
      H.eq(totals.fcache_hitted, 1, "and disk hits -- an unrecognised type is ignored, not miscounted")
    end)

    with_metrics({ log_path = false }, function(metrics, notes)
      local totals = metrics.get_total_requests()
      H.eq(totals.successful, 0, "without a log path the totals are zero")
      H.contains(table.concat(notes, "\n"), "logfile path invalid", "and the reason is reported")
    end)

    vim.fn.writefile({ "{not json" }, log_path)
    with_metrics({}, function(metrics, notes)
      H.eq(metrics.get_total_requests().successful, 0, "a corrupt log totals zero")
      H.contains(table.concat(notes, "\n"), "Error reading stats file", "and is reported")
    end)

    -------------------------------------------------------------------------
    -- The rate-limit probe
    -------------------------------------------------------------------------
    -- With limits already known, no request is made -- only a warning when
    -- usage crosses a threshold.
    with_metrics({}, function(metrics, notes)
      local requested = 0
      H.with_stubs({
        ["reposcope.network.clients.api_client"] = {
          request = function() requested = requested + 1 end,
        },
      }, {}, function()
        metrics.rate_limits.core = { limit = 5000, remaining = 4000, reset = 0 }
        metrics.rate_limits.search = { limit = 30, remaining = 29, reset = 0 }
        metrics.check_rate_limit()
        vim.wait(50)
        H.eq(requested, 0, "known limits need no probe")
        H.eq(#notes, 0, "and 20% used is not worth a message")

        metrics.rate_limits.core = { limit = 5000, remaining = 1000, reset = 0 }
        metrics.check_rate_limit()
        vim.wait(50)
        H.contains(table.concat(notes, "\n"), "Core limit approaching", "80% used is an advisory")

        metrics.rate_limits.core = { limit = 5000, remaining = 100, reset = 0 }
        metrics.check_rate_limit()
        vim.wait(50)
        H.contains(table.concat(notes, "\n"), "Core limit critical", "98% used is a warning")

        metrics.rate_limits.search = { limit = 30, remaining = 1, reset = 0 }
        metrics.check_rate_limit()
        vim.wait(50)
        H.contains(table.concat(notes, "\n"), "Search limit critical", "and the search budget is reported separately")
      end)
    end)

    -- With no limits known yet, one probe is made -- and its answer is stored.
    with_metrics({ token = "gho_x" }, function(metrics)
      local requests = {}
      H.with_stubs({
        ["reposcope.network.clients.api_client"] = {
          request = function(method, url, callback, headers)
            requests[#requests + 1] = { method = method, url = url, headers = headers, callback = callback }
          end,
        },
      }, {}, function()
        metrics.rate_limits.core = { limit = 0, remaining = 0, reset = 0 }
        metrics.rate_limits.search = { limit = 0, remaining = 0, reset = 0 }
        metrics.check_rate_limit()

        H.eq(#requests, 1, "an unknown limit is probed exactly once")
        H.eq(requests[1].url, "https://api.github.com/rate_limit", "against the rate_limit endpoint")
        H.eq(requests[1].headers["Authorization"], "Bearer gho_x", "carrying the configured token")

        requests[1].callback(
          vim.json.encode({
            resources = {
              core = { limit = 5000, remaining = 4999, reset = 111 },
              search = { limit = 30, remaining = 30, reset = 222 },
            },
          }),
          nil
        )
        H.eq(metrics.rate_limits.core.limit, 5000, "the core budget is stored")
        H.eq(metrics.rate_limits.core.remaining, 4999, "with what is left")
        H.eq(metrics.rate_limits.core.reset, 111, "and when it resets")
        H.eq(metrics.rate_limits.search.limit, 30, "the search budget too")
      end)
    end)

    with_metrics({}, function(metrics, notes)
      H.with_stubs({
        ["reposcope.network.clients.api_client"] = {
          request = function(_, _, callback) callback(nil, "HTTP 401") end,
        },
      }, {}, function()
        metrics.rate_limits.core = { limit = 0, remaining = 0, reset = 0 }
        metrics.rate_limits.search = { limit = 0, remaining = 0, reset = 0 }
        metrics.check_rate_limit()
        vim.wait(50)
        H.contains(table.concat(notes, "\n"), "Failed to fetch GitHub rate limit", "a failed probe is reported")
        H.eq(metrics.rate_limits.core.limit, 0, "and nothing is stored")
      end)
    end)

    -- A response body that isn't JSON at all must not raise out of the
    -- callback -- it goes through `pcall` and is reported like any other
    -- failure instead (ERR-01).
    with_metrics({}, function(metrics, notes)
      H.with_stubs({
        ["reposcope.network.clients.api_client"] = {
          request = function(_, _, callback) callback("<html>not json</html>", nil) end,
        },
      }, {}, function()
        metrics.rate_limits.core = { limit = 0, remaining = 0, reset = 0 }
        metrics.rate_limits.search = { limit = 0, remaining = 0, reset = 0 }
        local ok = pcall(metrics.check_rate_limit)
        vim.wait(50)
        H.ok(ok, "a non-JSON body does not raise")
        H.contains(table.concat(notes, "\n"), "Invalid rate limit response", "and is reported instead")
        H.eq(metrics.rate_limits.core.limit, 0, "and nothing is stored")
      end)
    end)

    -- A body that decodes but is missing `resources.core`/`resources.search`
    -- must not raise on the nested index either.
    with_metrics({}, function(metrics, notes)
      H.with_stubs({
        ["reposcope.network.clients.api_client"] = {
          request = function(_, _, callback) callback(vim.json.encode({ resources = {} }), nil) end,
        },
      }, {}, function()
        metrics.rate_limits.core = { limit = 0, remaining = 0, reset = 0 }
        metrics.rate_limits.search = { limit = 0, remaining = 0, reset = 0 }
        local ok = pcall(metrics.check_rate_limit)
        vim.wait(50)
        H.ok(ok, "a response missing core/search does not raise")
        H.contains(table.concat(notes, "\n"), "missing core/search data", "and is reported instead")
        H.eq(metrics.rate_limits.core.limit, 0, "and nothing is stored")
      end)
    end)

    -------------------------------------------------------------------------
    -- utils.stats: the aggregations behind `:Reposcope stats`
    -------------------------------------------------------------------------
    local function with_stats(fn)
      H.with_stubs({
        ["reposcope.config"] = {
          options = { metrics = true, log_max = 1000 },
          get_option = function(key)
            if key == "logfile_path" then return log_path end
            return nil
          end,
        },
      }, { "reposcope.utils.stats", "reposcope.utils.metrics" }, function() fn(require("reposcope.utils.stats")) end)
    end

    vim.fn.writefile({
      vim.json.encode({
        ["a:api_success"] = { type = "api_success", duration_ms = 10, query = "alpha" },
        ["b:api_success"] = { type = "api_success", duration_ms = 30, query = "alpha" },
        ["c:api_failed"] = { type = "api_failed", query = "beta" },
      }),
    }, log_path)

    with_stats(function(stats)
      local average, frequent = stats.calculate_extended_stats()
      -- The average is over *successful* requests only: a failure that
      -- returned in 1ms because the host refused the connection says nothing
      -- about how fast the API is.
      H.eq(average, 20, "the average duration is taken over successful requests only")
      H.eq(frequent, "alpha", "and the most frequent query wins")

      H.eq(stats.get_most_frequent_query({}), "N/A", "with no queries at all there is no answer")
      H.eq(stats.get_most_frequent_query({ only = 1 }), "only", "a single query is trivially the most frequent")
      H.eq(stats.get_most_frequent_query({ a = 5, b = 2 }), "a", "otherwise the highest count wins")
    end)

    vim.fn.delete(log_path)
    with_stats(function(stats)
      local average, frequent = stats.calculate_extended_stats()
      H.eq(average, 0, "with no log file the average is zero")
      H.eq(frequent, "N/A", "and there is no most-frequent query")
    end)

    vim.fn.writefile({ "{not json" }, log_path)
    with_stats(function(stats)
      local average, frequent = stats.calculate_extended_stats()
      H.eq(average, 0, "a corrupt log yields zero rather than raising")
      H.eq(frequent, "N/A", "and no query")
    end)

    -- Only failures logged: the divide-by-zero guard.
    vim.fn.writefile({ vim.json.encode({ ["c:api_failed"] = { type = "api_failed", query = "beta" } }) }, log_path)
    with_stats(function(stats)
      local average, frequent = stats.calculate_extended_stats()
      H.eq(average, 0, "with no successful request there is no average to divide")
      H.eq(frequent, "beta", "but a failed request's query still counts towards frequency")
    end)
  end)

  cleanup()
  if not ok then error(err, 0) end
end
