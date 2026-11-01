# fadein.nvim

![Demo](demo.gif)

Requires Neovim 0.10+ and [snacks.nvim](https://github.com/folke/snacks.nvim).

## Install

With [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
  "folke/snacks.nvim",
  lazy = false,
  priority = 1000,
  dependencies = { "CruelAddict/fadein.nvim" },
  opts = function()
    return {
      dashboard = {
        enabled = true,
        sections = {
          require("fadein").section({ animation = "n" }),
          { section = "keys", padding = 1 },
          { section = "startup" },
        },
      },
    }
  end,
}
```

Already using Snacks? Add the dependency and replace `{ section = "header" }`
with `require("fadein").section({ animation = "n" })` in `dashboard.sections`.

`animation` defaults to `"n"`; `speed` defaults to `1`.
