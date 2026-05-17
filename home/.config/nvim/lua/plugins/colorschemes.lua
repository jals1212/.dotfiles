-- Theme is selected by the dots installer. Keep source defaults usable before deploy.
local selected_theme = "DOTS_THEME"
local selected_flavor = "DOTS_FLAVOR"

if selected_theme == "DOTS_THEME" or selected_theme == "" then
  selected_theme = "kanagawa"
end
if selected_flavor == "DOTS_FLAVOR" or selected_flavor == "" then
  selected_flavor = selected_theme == "catppuccin" and "mocha" or "dragon"
end

local lazyvim_colorscheme = selected_theme == "catppuccin" and "catppuccin" or "kanagawa"

return {
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = lazyvim_colorscheme,
    },
  },
  {
    "catppuccin/nvim",
    name = "catppuccin",
    priority = 1000,
    enabled = function()
      return selected_theme == "catppuccin"
    end,
    config = function()
      require("catppuccin").setup({
        flavour = selected_flavor,
        transparent_background = false,
        term_colors = true,
        integrations = {
          cmp = true,
          gitsigns = true,
          neo_tree = true,
          telescope = true,
          treesitter = true,
          which_key = true,
        },
      })
      vim.cmd.colorscheme("catppuccin")
    end,
  },
  {
    "rebelot/kanagawa.nvim",
    priority = 1000,
    enabled = function()
      return selected_theme == "kanagawa"
    end,
    config = function()
      require("kanagawa").setup({
        compile = false,
        undercurl = true,
        commentStyle = { italic = true },
        keywordStyle = { italic = true },
        statementStyle = { bold = true },
        transparent = false,
        dimInactive = false,
        terminalColors = true,
        theme = selected_flavor,
        background = {
          dark = selected_flavor == "dragon" and "dragon" or "wave",
          light = "lotus",
        },
      })
      vim.cmd.colorscheme("kanagawa")
    end,
  },
}
