return {
  {
    "alexghergh/nvim-tmux-navigation",
    keys = {
      { "<C-h>", desc = "Go to left window/pane" },
      { "<C-j>", desc = "Go to lower window/pane" },
      { "<C-k>", desc = "Go to upper window/pane" },
      { "<C-l>", desc = "Go to right window/pane" },
      { "<C-\\>", desc = "Go to last active window/pane" },
      { "<C-Space>", desc = "Go to next window/pane" },
    },
  },

  {
    "ibhagwan/fzf-lua",
    cmd = "FzfLua",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = {
      files = {
        fd_opts = "--color=never --type f --hidden --follow --exclude .git --exclude node_modules",
      },
      grep = {
        rg_opts = "--column --line-number --no-heading --color=always --smart-case --hidden --glob !.git --glob !node_modules",
      },
    },
  },

  {
    "rmagatti/goto-preview",
    event = "BufEnter",
    opts = {},
    keys = {
      { "gpd", "<cmd>lua require('goto-preview').goto_preview_definition()<CR>", desc = "Preview definition" },
      { "gpD", "<cmd>lua require('goto-preview').goto_preview_declaration()<CR>", desc = "Preview declaration" },
      { "gpi", "<cmd>lua require('goto-preview').goto_preview_implementation()<CR>", desc = "Preview implementation" },
      { "gpy", "<cmd>lua require('goto-preview').goto_preview_type_definition()<CR>", desc = "Preview type definition" },
      { "gpr", "<cmd>lua require('goto-preview').goto_preview_references()<CR>", desc = "Preview references" },
      { "gP", "<cmd>lua require('goto-preview').close_all_win()<CR>", desc = "Close preview windows" },
    },
  },

  {
    "simrat39/symbols-outline.nvim",
    cmd = "SymbolsOutline",
    keys = {
      { "<leader>cs", "<cmd>SymbolsOutline<CR>", desc = "Symbols outline" },
    },
    config = true,
  },

  {
    "chrisgrieser/nvim-rip-substitute",
    cmd = "RipSubstitute",
    keys = {
      {
        "<leader>fs",
        function()
          require("rip-substitute").sub()
        end,
        mode = { "n", "x" },
        desc = "Rip substitute",
      },
    },
  },

  {
    "folke/trouble.nvim",
    opts = { use_diagnostic_signs = true },
  },
}
