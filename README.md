# fadein.nvim

An animated neovim logo that makes your startup dashboard stylish but not
distracting.

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
          -- instead of "header" section
          require("fadein").section({ animation = "n" }),
          { section = "keys", padding = 1 },
          { section = "startup" },
        },
      },
    }
  end,
}
```

## Horizontal layout

For the animation on the left and the menu on the right, as shown in the
showcase gif above:

```lua
dashboard = {
  enabled = true,
  width = 40,
  pane_gap = 6,
  sections = {
    require("fadein").section({ animation = "n" }),
    { section = "keys", pane = 2, gap = 1, padding = 1 },
    { section = "startup", pane = 2 },
  },
}
```
