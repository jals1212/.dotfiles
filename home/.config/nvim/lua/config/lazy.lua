-- Lazy.nvim + LazyVim bootstrap.

local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
local lazyvimpath = vim.fn.stdpath("data") .. "/lazy/LazyVim"
local fs_stat = vim.uv and vim.uv.fs_stat or vim.loop.fs_stat
local no_install = vim.env.DOTS_NVIM_NO_INSTALL == "1"

if not fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable",
    lazypath,
  })
end

vim.opt.rtp:prepend(vim.env.LAZY or lazypath)

local spec = {}
local include_lazyvim = not (no_install and not fs_stat(lazyvimpath))

if include_lazyvim then
  table.insert(spec, { "LazyVim/LazyVim", import = "lazyvim.plugins" })
  table.insert(spec, { import = "lazyvim.plugins.extras.editor.snacks_picker" })
  table.insert(spec, { import = "lazyvim.plugins.extras.editor.mini-diff" })
  table.insert(spec, { import = "lazyvim.plugins.extras.coding.mini-surround" })
  table.insert(spec, { import = "lazyvim.plugins.extras.util.mini-hipatterns" })
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.json" })
  table.insert(spec, { import = "lazyvim.plugins.extras.lang.markdown" })
  table.insert(spec, { import = "lazyvim.plugins.extras.dap.core" })
end
table.insert(spec, { import = "plugins" })

require("lazy").setup({
  spec = spec,
  defaults = {
    lazy = false,
    version = false,
  },
  install = {
    missing = not no_install,
    colorscheme = { "catppuccin", "kanagawa", "habamax" },
  },
  checker = { enabled = false, notify = false },
  change_detection = { notify = false },
  performance = {
    rtp = {
      disabled_plugins = {
        "gzip",
        "tarPlugin",
        "tohtml",
        "tutor",
        "zipPlugin",
      },
    },
  },
})
