-- Test code: when something here comes back nil -- a `pcall(require, ...)`,
-- a fixture read, a uv handle -- this file must crash and name it. The nil
-- guards LuaLS asks for below would hide the very failure it exists to report.
---@diagnostic disable: need-check-nil
-- TESTS/readme_cache_spec.lua — the two-tier README cache (RAM + disk) and
-- its freshness sidecar.
--
-- Runs against a real fixture directory inside the repository, with
-- `config.get_readme_filecache_dir`/`get_readme_meta_path` redirected into it
-- before the cache module is (re)loaded -- it binds both to file-local
-- upvalues at load time. Nothing here touches the user's real cache.

return function(H)
  local dir, cleanup = H.fixture("readme_cache")
  local config = require("reposcope.config")
  local saved_dir_fn, saved_meta_fn = config.get_readme_filecache_dir, config.get_readme_meta_path

  local cache_dir = dir .. "/readme"
  local meta_path = dir .. "/readme_meta.json"
  config.get_readme_filecache_dir = function() return cache_dir end
  config.get_readme_meta_path = function() return meta_path end

  ---Fresh cache module, with the fixture paths bound.
  local function reload()
    package.loaded["reposcope.cache.readme_cache"] = nil
    return require("reposcope.cache.readme_cache")
  end

  local ok, err = pcall(function()
    ---------------------------------------------------------------------------
    -- A name that came off the network never escapes the cache directory
    ---------------------------------------------------------------------------
    do
      local cache = reload()

      local normal = cache.file_path("nvim-telescope", "telescope.nvim")
      H.eq(normal, cache_dir .. "/nvim-telescope__telescope.nvim.md", "an ordinary name maps straight onto the layout")

      -- `owner` and `repo` are fields of an API response and are concatenated
      -- into a filesystem path. A hostile host answering with `..` must not be
      -- able to write outside the cache.
      -- The dot itself is legal in a repository name, so it is not stripped;
      -- what makes traversal impossible is that every *separator* is. The
      -- result is one flat filename that happens to contain dots.
      local traversal = cache.file_path("../../etc", "passwd")
      H.eq(traversal, cache_dir .. "/.._.._etc__passwd.md", "the separators are gone, the dots are inert")
      H.eq(traversal:sub(1, #cache_dir + 1), cache_dir .. "/", "so the path still starts inside the cache directory")
      H.excludes(traversal:sub(#cache_dir + 2), "/", "and the remainder is a single name, with no further segment")

      H.eq(cache.file_path("..", "r"), cache_dir .. "/___r.md", "a segment of only dots is refused outright")
      H.eq(cache.file_path("", "r"), cache_dir .. "/___r.md", "so is an empty one")
      H.excludes(cache.file_path("a/../../b", "r"), "/../", "and a compound traversal has no usable separator left")
      H.excludes(cache.file_path("a\\..\\b", "r"), "\\", "a Windows separator is neutralised the same way")

      -- Characters a real forge does allow survive unchanged, so the
      -- sanitiser is not quietly renaming legitimate repositories.
      H.eq(
        cache.file_path("Stefan-Bartl", "color_my_ascii.nvim"),
        cache_dir .. "/Stefan-Bartl__color_my_ascii.nvim.md",
        "dots, dashes and underscores are legal and are left alone"
      )
    end

    ---------------------------------------------------------------------------
    -- RAM, disk, and which one answers
    ---------------------------------------------------------------------------
    do
      local cache = reload()

      local has, source = cache.has("o", "r")
      H.falsy(has, "an unknown repository is not cached")
      H.eq(source, nil, "and has no source")
      H.eq(cache.get("o", "r"), nil, "reading it yields nil rather than an error")

      cache.set_ram("o", "r", "# in memory")
      has, source = cache.has("o", "r")
      H.ok(has, "a RAM entry counts as cached")
      H.eq(source, "ram", "and reports RAM as the source")
      H.eq(cache.get("o", "r"), "# in memory", "reading it returns the content")
      H.eq(vim.fn.filereadable(cache.file_path("o", "r")), 0, "without having touched the disk")

      H.ok(cache.set_file("o2", "r2", "# on disk"), "writing to the file cache reports success")
      H.eq(H.read(cache.file_path("o2", "r2")), "# on disk", "and the bytes are there")
      has, source = cache.has("o2", "r2")
      H.ok(has, "a disk entry counts as cached")
      H.eq(source, "file", "and reports the file as the source")

      -- Reading from disk promotes into RAM, so the second navigation to the
      -- same repository costs nothing.
      H.eq(cache.get_ram("o2", "r2"), nil, "before reading, nothing is in RAM")
      -- Round-tripping through the file cache appends a trailing newline
      -- (lib.nvim's writer terminates the last line); harmless for markdown,
      -- but stated so a change to it is deliberate.
      H.eq(cache.get("o2", "r2"), "# on disk\n", "the disk entry is read, newline-terminated")
      H.eq(cache.get_ram("o2", "r2"), "# on disk\n", "and promoted into RAM as a side effect")

      -- RAM wins over disk once both exist.
      cache.set_ram("o2", "r2", "# newer")
      H.eq(cache.get("o2", "r2"), "# newer", "RAM is preferred over the older file")

      -- set_file always overwrites: every caller reaches it after a real fetch.
      cache.set_file("o2", "r2", "# replaced")
      H.eq(H.read(cache.file_path("o2", "r2")), "# replaced", "a second write replaces the first")
    end

    ---------------------------------------------------------------------------
    -- Freshness: the sidecar decides whether a cache hit is usable
    ---------------------------------------------------------------------------
    do
      vim.fn.delete(meta_path)
      local cache = reload()
      cache.set_file("o", "r", "# content")

      H.eq(cache.get_cached_updated_at("o", "r"), nil, "nothing is recorded yet")
      H.ok(cache.has_fresh("o", "r", nil), "with no updated_at to compare, the cache is trusted")
      H.ok(cache.has_fresh("o", "r", ""), "an empty updated_at is the same non-information")
      H.ok(
        cache.has_fresh("o", "r", "2026-01-01"),
        "and an unrecorded entry is trusted too -- there is nothing to contradict it"
      )

      cache.set_updated_at("o", "r", "2026-01-01")
      H.eq(cache.get_cached_updated_at("o", "r"), "2026-01-01", "the value is recorded")
      H.ok(vim.fn.filereadable(meta_path) == 1, "and persisted to the sidecar file")

      local fresh, source = cache.has_fresh("o", "r", "2026-01-01")
      H.ok(fresh, "an unchanged repository is still fresh")
      H.eq(source, "file", "and the source is reported")

      fresh, source = cache.has_fresh("o", "r", "2026-06-01")
      H.falsy(fresh, "a repository that changed since caching is a miss")
      H.eq(source, nil, "with no source -- the caller must re-fetch")

      H.falsy(cache.has_fresh("unknown", "repo", "2026-01-01"), "an uncached repository is a miss regardless")

      -- A nil/empty updated_at records nothing rather than storing a blank.
      cache.set_updated_at("o", "r", nil)
      H.eq(cache.get_cached_updated_at("o", "r"), "2026-01-01", "a nil updated_at does not clear the recorded value")
      cache.set_updated_at("o", "r", "")
      H.eq(cache.get_cached_updated_at("o", "r"), "2026-01-01", "neither does an empty one")

      -- The sidecar survives a reload from disk.
      local reloaded = reload()
      H.eq(reloaded.get_cached_updated_at("o", "r"), "2026-01-01", "the sidecar is read back on the next session")
    end

    ---------------------------------------------------------------------------
    -- A corrupt sidecar is survivable -- and backed up rather than silently
    -- discarded by the next set_updated_at()'s overwrite (ERR-11).
    ---------------------------------------------------------------------------
    do
      local corrupt_path = meta_path .. ".corrupt"
      vim.fn.delete(corrupt_path)
      vim.fn.writefile({ "{not json" }, meta_path)
      local cache = reload()
      H.eq(cache.get_cached_updated_at("o", "r"), nil, "a corrupt sidecar reads as empty rather than raising")
      H.ok(vim.fn.filereadable(corrupt_path) == 1, "corrupt sidecar was backed up to readme_meta.json.corrupt")
      H.eq(H.read(corrupt_path), "{not json", "backup preserves the original corrupt bytes")
      cache.set_file("o", "r", "x")
      H.ok(cache.has_fresh("o", "r", "anything"), "and degrades to plain `has` -- the content itself is still usable")

      -- The write below (via set_updated_at) rewrites the whole sidecar --
      -- it must not touch the backup that already preserves the original.
      cache.set_updated_at("o", "r", "2026-02-02")
      H.eq(H.read(corrupt_path), "{not json", "a later save does not overwrite the existing backup")
      vim.fn.delete(corrupt_path)
    end

    ---------------------------------------------------------------------------
    -- Clearing
    ---------------------------------------------------------------------------
    do
      vim.fn.delete(meta_path)
      local cache = reload()

      H.falsy(cache.clear("nope", "nothing"), "clearing something that is not cached reports nothing was cleared")

      cache.set_ram("o", "r", "x")
      cache.set_file("o", "r", "x")
      cache.set_updated_at("o", "r", "2026-01-01")

      H.ok(cache.clear("o", "r", "ram"), "clearing RAM reports success")
      H.eq(cache.get_ram("o", "r"), nil, "RAM is empty")
      H.eq(vim.fn.filereadable(cache.file_path("o", "r")), 1, "but the file survives")

      H.ok(cache.clear("o", "r", "file"), "clearing the file reports success")
      H.eq(vim.fn.filereadable(cache.file_path("o", "r")), 0, "and the file is gone")
      H.eq(cache.get_cached_updated_at("o", "r"), nil, "the freshness record goes with it")

      cache.set_ram("both", "r", "x")
      cache.set_file("both", "r", "x")
      H.ok(cache.clear("both", "r"), "the default target is both tiers")
      H.eq(cache.get_ram("both", "r"), nil, "RAM cleared")
      H.eq(vim.fn.filereadable(cache.file_path("both", "r")), 0, "file cleared")
    end

    ---------------------------------------------------------------------------
    -- clear_all
    ---------------------------------------------------------------------------
    do
      local cache = reload()
      cache.set_ram("a", "b", "x")
      cache.set_file("a", "b", "x")
      cache.set_file("c", "d", "y")
      cache.set_updated_at("a", "b", "2026-01-01")

      H.ok(cache.clear_all(), "clear_all succeeds")
      H.eq(cache.get_ram("a", "b"), nil, "RAM is empty")
      H.eq(vim.fn.filereadable(cache.file_path("a", "b")), 0, "the first file is gone")
      H.eq(vim.fn.filereadable(cache.file_path("c", "d")), 0, "and so is the second")
      H.eq(cache.get_cached_updated_at("a", "b"), nil, "the freshness sidecar is emptied too")

      -- The cache directory is created lazily by the first write, so
      -- clear_all has to cope with it not existing. `vim.fn.readdir` on a
      -- missing directory does not raise -- it *echoes* E484 and returns an
      -- empty list, which a pcall cannot suppress.
      vim.fn.delete(cache_dir, "rf")
      H.ok(reload().clear_all(), "clear_all on a cache that was never written still succeeds")
    end

    ---------------------------------------------------------------------------
    -- Warming RAM from the file cache at startup
    ---------------------------------------------------------------------------
    do
      vim.fn.delete(cache_dir, "rf")
      H.eq(reload().warm_ram_from_file_cache(), 0, "a missing cache directory warms nothing, silently")

      local cache = reload()
      cache.set_file("owner-a", "repo-a", "# a")
      cache.set_file("owner-b", "repo-b", "# b")
      -- Not one of ours: the filename pattern has to reject it.
      vim.fn.writefile({ "junk" }, cache_dir .. "/not-a-cache-entry.txt")

      local warm = reload()
      H.eq(warm.warm_ram_from_file_cache(), 2, "both cached READMEs are loaded")
      H.eq(warm.get_ram("owner-a", "repo-a"), "# a\n", "the first is in RAM")
      H.eq(warm.get_ram("owner-b", "repo-b"), "# b\n", "and the second")

      -- Running it twice must not double-count: an entry already in RAM is skipped.
      H.eq(warm.warm_ram_from_file_cache(), 0, "a second warm-up loads nothing -- everything is already in RAM")
    end
  end)

  config.get_readme_filecache_dir = saved_dir_fn
  config.get_readme_meta_path = saved_meta_fn
  package.loaded["reposcope.cache.readme_cache"] = nil
  cleanup()

  if not ok then error(err, 0) end
end
