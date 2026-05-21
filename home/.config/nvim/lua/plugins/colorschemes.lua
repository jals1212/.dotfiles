-- colorschemes.lua — load active theme via ~/.config/nvim/lua/dots-theme.lua
-- (linked by the per-theme dotbot config; see themes/<theme>-<flavor>.yaml).

local ok, dots = pcall(require, "dots-theme")
if not ok then
  -- Fallback for first-run or broken link: pick a sane default.
  dots = {
    theme = "kanagawa",
    flavor = "dragon",
    plugin = "rebelot/kanagawa.nvim",
    colorscheme = "kanagawa-dragon",
  }
end

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
      local plugin_name = dots.plugin:match("([^/]+)$"):gsub("%.nvim$", "")
      local mod_ok, mod = pcall(require, plugin_name)
      if mod_ok and mod.setup then
        mod.setup(opts)
      end
      pcall(vim.cmd, "colorscheme " .. dots.colorscheme)
    end,
  },
}
