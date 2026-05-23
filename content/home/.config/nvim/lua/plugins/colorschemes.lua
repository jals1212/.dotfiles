-- colorschemes.lua — load active theme from the repo-local manifest.json.

local dots = require("config.dots_theme").current()

return {
  {
    dots.plugin,
    lazy = false,
    priority = 1000,
    opts = function()
      -- Plugin-specific opts. Most plugins accept { flavour = ... } or
      -- the equivalent. Adjust here if a future plugin needs different
      -- key names; the table reaches every supported variant.
      return { flavour = dots.flavor, flavor = dots.flavor }
    end,
    config = function(_, opts)
      local plugin_name = dots.plugin == "catppuccin/nvim" and "catppuccin"
        or dots.plugin:match("([^/]+)$"):gsub("%.nvim$", "")
      local mod_ok, mod = pcall(require, plugin_name)
      if mod_ok and mod.setup then
        mod.setup(opts)
      end
      pcall(vim.cmd, "colorscheme " .. dots.colorscheme)
    end,
  },
}
