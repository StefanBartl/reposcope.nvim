# Installation

### With [Lazy.nvim](https://github.com/folke/lazy.nvim)

```lua
{
  "StefanBartl/reposcope.nvim",
  name = "reposcope",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  config = function()
    require("reposcope.init").setup({})
  end,
}
```

### With [packer.nvim](https://github.com/wbthomason/packer.nvim)

```lua
use {
  "StefanBartl/reposcope.nvim",
  name = "reposcope",
  dependencies = { "StefanBartl/lib.nvim" },
  event = "VeryLazy",
  config = function()
    require("reposcope.init").setup({})
  end,
}
```
