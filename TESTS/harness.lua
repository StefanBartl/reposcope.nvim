-- TESTS/harness.lua — tiny assertion helper shared by the spec files.
-- Returned to each spec by TESTS/run.lua.

local H = {}

--- Assert equality; raises a descriptive error on mismatch (caught by the runner).
---@param a any # actual
---@param b any # expected
---@param msg string|nil
function H.eq(a, b, msg)
  if a ~= b then error(("FAIL %s: expected %q, got %q"):format(msg or "", tostring(b), tostring(a)), 2) end
end

--- Assert a truthy value.
---@param v any
---@param msg string|nil
function H.ok(v, msg)
  if not v then error(("FAIL %s: expected truthy, got %q"):format(msg or "", tostring(v)), 2) end
end

--- Assert a falsy value.
---@param v any
---@param msg string|nil
function H.falsy(v, msg)
  if v then error(("FAIL %s: expected falsy, got %q"):format(msg or "", tostring(v)), 2) end
end

--- Assert that `haystack` contains `needle` as a literal substring.
---@param haystack string
---@param needle string
---@param msg string|nil
function H.contains(haystack, needle, msg)
  if type(haystack) ~= "string" or not haystack:find(needle, 1, true) then
    error(("FAIL %s: %q does not contain %q"):format(msg or "", tostring(haystack), needle), 2)
  end
end

--- Assert that `haystack` does NOT contain `needle`.
---@param haystack string
---@param needle string
---@param msg string|nil
function H.excludes(haystack, needle, msg)
  if type(haystack) == "string" and haystack:find(needle, 1, true) then
    error(("FAIL %s: %q still contains %q"):format(msg or "", tostring(haystack), needle), 2)
  end
end

--- Runs `fn` with `stubs` installed in `package.loaded` and `reload` dropped
--- from it, then restores `package.loaded` to exactly what it was.
---
--- Every module in this plugin binds its dependencies to file-local upvalues
--- at load time (`local x = require(...).x`), so patching a field on an
--- already-loaded module afterwards is too late -- the module under test is
--- still holding the original function. The seam that does work is replacing
--- the dependency in `package.loaded` and then requiring the subject *fresh*,
--- which is what `reload` is for: list the subject plus every module between
--- it and the stub.
---
--- Restoration is a whole-table snapshot rather than key-by-key, so a module
--- the body pulled in transitively (and which therefore captured a stub)
--- cannot leak into a later spec.
---@param stubs table<string, any>|nil Modules to place in `package.loaded`
---@param reload string[]|nil Modules to unload, so the next `require` rebuilds them
---@param fn fun() Body; an error it raises is re-raised after restoration
---@return nil
function H.with_stubs(stubs, reload, fn)
  local before = {}
  for name, mod in pairs(package.loaded) do
    before[name] = mod
  end

  for _, name in ipairs(reload or {}) do
    package.loaded[name] = nil
  end
  for name, mod in pairs(stubs or {}) do
    package.loaded[name] = mod
  end

  local ok, err = pcall(fn)

  for name in pairs(package.loaded) do
    if before[name] == nil then package.loaded[name] = nil end
  end
  for name, mod in pairs(before) do
    package.loaded[name] = mod
  end

  if not ok then error(err, 0) end
end

--- The index of `needle` in the list `haystack`, or nil.
---
--- Used to assert on argv tables, where "the flag is present" is a much
--- weaker statement than "the flag is present and its value is the element
--- right after it".
---@param haystack any[]
---@param needle any
---@return integer|nil
function H.index_of(haystack, needle)
  for i = 1, #haystack do
    if haystack[i] == needle then return i end
  end
  return nil
end

--- Assert that the list `haystack` contains `needle`.
---@param haystack any[]
---@param needle any
---@param msg string|nil
function H.has(haystack, needle, msg)
  if not H.index_of(haystack, needle) then
    error(("FAIL %s: %s does not contain %q"):format(msg or "", vim.inspect(haystack), tostring(needle)), 2)
  end
end

--- Assert that the list `haystack` does NOT contain `needle`.
---@param haystack any[]
---@param needle any
---@param msg string|nil
function H.lacks(haystack, needle, msg)
  if H.index_of(haystack, needle) then
    error(("FAIL %s: %s still contains %q"):format(msg or "", vim.inspect(haystack), tostring(needle)), 2)
  end
end

--- Drains the scheduled-callback queue, so a `vim.schedule`d assertion has
--- actually run by the time the spec checks its effect. `vim.wait` with a
--- zero-argument condition still yields to the event loop on each tick.
---@param ticks integer|nil Number of loop turns to give away (default 3)
---@return nil
function H.drain(ticks)
  for _ = 1, ticks or 3 do
    vim.wait(0)
  end
end

--- A scratch directory inside the repository, removed by `cleanup()`.
---
--- Inside the repo rather than in `vim.fn.tempname()` on purpose: on Windows
--- the temp path carries an 8.3 short component (`STEFAN~1`), which several
--- Vim path builtins do not see through -- a fixture there would pass on Linux
--- and quietly assert nothing locally.
---@param name string
---@return string dir, fun() cleanup
function H.fixture(name)
  local dir = vim.fs.normalize(vim.fn.getcwd()) .. "/TESTS/.fixture-" .. name
  vim.fn.delete(dir, "rf")
  vim.fn.mkdir(dir, "p")
  return dir, function() vim.fn.delete(dir, "rf") end
end

--- Read a file back as one string.
---@param path string
---@return string
function H.read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or type(lines) ~= "table" then return "" end
  return table.concat(lines, "\n")
end

return H
