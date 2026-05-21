-- Multi-cursor editing via vim-visual-multi.
-- Default trigger: <C-n> in normal mode (select word under cursor).
-- <C-n> is not bound by config/keymaps.lua, so plugin defaults are used.
-- Additional defaults: <C-Down>/<C-Up> add cursors, q skips, Q removes.
return {
  {
    "mg979/vim-visual-multi",
    branch = "master",
    event = "BufReadPost",
  },
}
