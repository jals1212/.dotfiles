-- Supplemental plugins that are not already owned by LazyVim core.
return {
  -- Fuzzy finder kept for repo keymaps that call Telescope commands.
  {
    "nvim-telescope/telescope.nvim",
    branch = "0.1.x",
    dependencies = { "nvim-lua/plenary.nvim" },
    cmd = "Telescope",
    config = function()
      require("telescope").setup({
        defaults = {
          file_ignore_patterns = { "node_modules", ".git/" },
        },
      })
    end,
  },

  -- Floating terminal.
  {
    "akinsho/toggleterm.nvim",
    version = "*",
    keys = {
      { "<leader>tt", "<cmd>ToggleTerm<cr>", desc = "Toggle terminal" },
    },
    config = function()
      require("toggleterm").setup({
        size = 20,
        direction = "float",
        float_opts = { border = "curved" },
      })
    end,
  },

  -- LazyGit command integration.
  {
    "kdheepak/lazygit.nvim",
    cmd = { "LazyGit", "LazyGitConfig" },
    dependencies = { "nvim-lua/plenary.nvim" },
  },
}
