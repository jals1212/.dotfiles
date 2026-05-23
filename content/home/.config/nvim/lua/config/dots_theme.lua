-- Resolve the active dotfiles theme from the repo-local manifest.json.
-- No mutable dots-theme.lua symlink is used.

local M = {}

local uv = vim.uv or vim.loop

local default_theme = {
  theme = "kanagawa",
  flavor = "dragon",
  plugin = "rebelot/kanagawa.nvim",
  colorscheme = "kanagawa-dragon",
}

local function stat(path)
  return path and uv.fs_stat(path) or nil
end

local function dirname(path)
  return vim.fs.dirname(path)
end

local function join(...)
  return table.concat({ ... }, "/")
end

local function repo_candidate(path)
  if not path or path == "" then
    return nil
  end
  local expanded = vim.fn.expand(path)
  if stat(join(expanded, "content", "themes", "index.yaml")) then
    return expanded
  end
  return nil
end

function M.repo_root()
  local env_root = repo_candidate(vim.env.DOTFILES) or repo_candidate(vim.env.DOTS_REPO)
  if env_root then
    return env_root
  end

  local home_root = repo_candidate("~/.dotfiles")
  if home_root then
    return home_root
  end

  local source = debug.getinfo(1, "S").source or ""
  if source:sub(1, 1) == "@" then
    source = source:sub(2)
  end

  local real = uv.fs_realpath(source) or source
  local dir = dirname(real)
  for _ = 1, 12 do
    if not dir or dir == "/" then
      break
    end
    if stat(join(dir, "content", "themes", "index.yaml")) then
      return dir
    end
    dir = dirname(dir)
  end

  return nil
end

local function read_file(path)
  local fd = io.open(path, "r")
  if not fd then
    return nil
  end
  local content = fd:read("*a")
  fd:close()
  return content
end

local function parse_manifest(path)
  local content = read_file(path)
  if not content then
    return nil
  end

  if vim.json and vim.json.decode then
    local ok, decoded = pcall(vim.json.decode, content)
    if ok and type(decoded) == "table" then
      return decoded
    end
  end

  return {
    theme = content:match('"theme"%s*:%s*"([^"]+)"'),
    flavor = content:match('"flavor"%s*:%s*"([^"]+)"'),
  }
end

local function load_palette(repo_root, theme, flavor)
  if not repo_root or not theme or not flavor then
    return nil
  end

  local path = join(repo_root, "content", "assets", "palettes", "nvim", theme .. "-" .. flavor .. ".lua")
  if not stat(path) then
    return nil
  end

  local ok, palette = pcall(dofile, path)
  if ok and type(palette) == "table" and palette.plugin and palette.colorscheme then
    return palette
  end
  return nil
end

function M.current()
  local repo_root = M.repo_root()
  local manifest = repo_root and parse_manifest(join(repo_root, "manifest.json")) or nil
  local palette = manifest and load_palette(repo_root, manifest.theme, manifest.flavor) or nil
  return palette or vim.deepcopy(default_theme)
end

function M.install_colorschemes()
  local current = M.current()
  return { current.colorscheme, "catppuccin", "kanagawa", "habamax" }
end

return M
