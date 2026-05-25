return {
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
}
