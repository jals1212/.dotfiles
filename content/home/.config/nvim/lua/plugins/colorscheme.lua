-- Colorscheme follows the active dots theme (see lua/config/theme.lua).
-- Both theme plugins are always declared (lazy-loaded) so a theme switch only
-- needs the colorscheme command; lazy.nvim loads the plugin on demand.
local palette = require("config.theme").get()

return {
  { "rebelot/kanagawa.nvim", lazy = true },
  { "catppuccin/nvim", name = "catppuccin", lazy = true, opts = { flavour = palette.flavor } },
  { "LazyVim/LazyVim", opts = { colorscheme = palette.colorscheme } },
}
