-- Dotfiles — Neovim (LazyVim)

-- Leader key (must be set before lazy.nvim and LazyVim)
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Load repo-specific config before plugin setup.
require("config.options")
require("config.keymaps")
require("config.nodejs").setup({ silent = true })

-- Bootstrap lazy.nvim, LazyVim, and repo plugins.
require("config.lazy")
