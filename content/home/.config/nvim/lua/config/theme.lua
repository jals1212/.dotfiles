-- Active dots theme for Neovim.
--
-- `./dots theme <theme> <flavor>` points lua/dots-theme.lua (a gitignored
-- symlink) at content/assets/palettes/nvim/<theme>-<flavor>.lua, a table of
-- { theme, flavor, plugin, colorscheme }. This module reads it, and falls back
-- to the dots default when the link is missing or unusable.
local M = {}

M.fallback = {
  theme = "kanagawa",
  flavor = "wave",
  plugin = "rebelot/kanagawa.nvim",
  colorscheme = "kanagawa-wave",
}

M.path = vim.fn.stdpath("config") .. "/lua/dots-theme.lua"

--- Read the active palette table; never raises.
---@return { theme: string, flavor: string, plugin: string, colorscheme: string }
function M.get()
  if (vim.uv or vim.loop).fs_stat(M.path) then
    local ok, palette = pcall(dofile, M.path)
    if ok and type(palette) == "table" and type(palette.colorscheme) == "string" then
      return vim.tbl_extend("keep", palette, M.fallback)
    end
  end
  return M.fallback
end

--- Re-read the link and apply the colorscheme when it changed (e.g. after
--- `./dots theme` ran in another terminal). Keeps the current colorscheme when
--- the new one cannot be loaded.
function M.reload()
  local wanted = M.get().colorscheme
  if wanted ~= vim.g.colors_name then
    pcall(vim.cmd.colorscheme, wanted)
  end
end

return M
