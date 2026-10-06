# Contribution

Issues, suggestions and pull requests are welcome!
Clone, symlink into your Neovim config, and hack away.

```
git clone https://github.com/StefanBartl/reposcope.nvim ~/.config/nvim/reposcope.nvim
```

[`lib.nvim`](https://github.com/StefanBartl/lib.nvim) and
[`ui.nvim`](https://github.com/StefanBartl/ui.nvim) are real runtime
dependencies — several modules require them at load — and the specs are run
by [`testing.nvim`](https://github.com/StefanBartl/testing.nvim), so check all
three out as sibling directories before running anything.

## Before opening a pull request

CI runs three gates, and each is one command locally:

```sh
stylua --check lua plugin TESTS
luacheck lua plugin TESTS
bash scripts/test.sh
```

The spec suite is described in [`../TESTS/README.md`](../TESTS/README.md),
including how to point it at a local `lib.nvim` and how to add a spec.
[`architecture.md`](architecture.md) is the map of where things live.
