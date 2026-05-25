return {
  {
    "amrbashir/nvim-docs-view",
    cmd = "DocsViewToggle",
    keys = {
      { "<leader>ud", "<cmd>DocsViewToggle<CR>", desc = "Toggle docs view" },
    },
    opts = {
      position = "right",
      width = 60,
    },
  },
}
