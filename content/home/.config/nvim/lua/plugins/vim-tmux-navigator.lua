-- Seamless pane navigation between tmux and nvim splits.
-- Counterpart of the `christoomey/vim-tmux-navigator` tmux plugin (tmux.conf).
return {
  "christoomey/vim-tmux-navigator",
  cmd = {
    "TmuxNavigateLeft",
    "TmuxNavigateDown",
    "TmuxNavigateUp",
    "TmuxNavigateRight",
    "TmuxNavigatePrevious",
  },
  keys = {
    { "<C-h>", "<cmd>TmuxNavigateLeft<cr>", desc = "Go to left window" },
    { "<C-j>", "<cmd>TmuxNavigateDown<cr>", desc = "Go to lower window" },
    { "<C-k>", "<cmd>TmuxNavigateUp<cr>", desc = "Go to upper window" },
    { "<C-l>", "<cmd>TmuxNavigateRight<cr>", desc = "Go to right window" },
    { "<C-\\>", "<cmd>TmuxNavigatePrevious<cr>", desc = "Go to previous window" },
  },
}
