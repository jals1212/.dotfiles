-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Follow `./dots theme` run elsewhere: re-read the active dots theme when
-- Neovim regains focus.
vim.api.nvim_create_autocmd("FocusGained", {
  group = vim.api.nvim_create_augroup("dots_theme", { clear = true }),
  callback = function()
    require("config.theme").reload()
  end,
})
