-- Custom keymaps
local map = vim.keymap.set

local function tmux_nav(method, fallback)
  return function()
    local ok, nav = pcall(require, "nvim-tmux-navigation")
    if ok and nav[method] then
      nav[method]()
      return
    end
    vim.cmd(fallback)
  end
end

-- Better window navigation, with tmux-pane awareness when available.
map("n", "<C-h>", tmux_nav("NvimTmuxNavigateLeft", "wincmd h"), { desc = "Go to left window/pane" })
map("n", "<C-j>", tmux_nav("NvimTmuxNavigateDown", "wincmd j"), { desc = "Go to lower window/pane" })
map("n", "<C-k>", tmux_nav("NvimTmuxNavigateUp", "wincmd k"), { desc = "Go to upper window/pane" })
map("n", "<C-l>", tmux_nav("NvimTmuxNavigateRight", "wincmd l"), { desc = "Go to right window/pane" })
map("n", "<C-\\>", tmux_nav("NvimTmuxNavigateLastActive", "wincmd p"), { desc = "Go to last active window/pane" })
map("n", "<C-Space>", tmux_nav("NvimTmuxNavigateNext", "wincmd w"), { desc = "Go to next window/pane" })

-- Resize windows
map("n", "<C-Up>", "<cmd>resize +2<cr>", { desc = "Increase window height" })
map("n", "<C-Down>", "<cmd>resize -2<cr>", { desc = "Decrease window height" })
map("n", "<C-Left>", "<cmd>vertical resize -2<cr>", { desc = "Decrease window width" })
map("n", "<C-Right>", "<cmd>vertical resize +2<cr>", { desc = "Increase window width" })

-- Buffer navigation
map("n", "<S-h>", "<cmd>bprevious<cr>", { desc = "Prev buffer" })
map("n", "<S-l>", "<cmd>bnext<cr>", { desc = "Next buffer" })
map("n", "<leader>bd", "<cmd>bdelete<cr>", { desc = "Delete buffer" })

-- File explorer
map("n", "<leader>e", "<cmd>Neotree toggle<cr>", { desc = "Toggle file explorer" })

-- Search (fzf-lua)
map("n", "<leader>ff", "<cmd>FzfLua files<cr>", { desc = "Find files" })
map("n", "<leader>fg", "<cmd>FzfLua live_grep<cr>", { desc = "Grep" })
map("n", "<leader>fb", "<cmd>FzfLua buffers<cr>", { desc = "Buffers" })
map("n", "<leader>fh", "<cmd>FzfLua help_tags<cr>", { desc = "Help" })
map("n", "<leader>fr", "<cmd>FzfLua oldfiles<cr>", { desc = "Recent files" })

-- Git
map("n", "<leader>gg", "<cmd>LazyGit<cr>", { desc = "LazyGit" })
map("n", "<leader>gb", "<cmd>Gitsigns blame_line<cr>", { desc = "Blame line" })
map("n", "<leader>gd", "<cmd>Gitsigns diffthis<cr>", { desc = "Diff this" })

-- Terminal
map("n", "<leader>tt", "<cmd>ToggleTerm<cr>", { desc = "Toggle terminal" })

-- Clear search
map("n", "<Esc>", "<cmd>noh<cr><Esc>", { desc = "Clear search highlight" })

-- Oil parent directory
vim.keymap.set("n", "-", "<CMD>Oil<CR>", { desc = "Open parent directory" })

-- Custom save function
function SaveFile()
  if vim.fn.empty(vim.fn.expand("%:t")) == 1 then
    vim.notify("No file to save", vim.log.levels.WARN)
    return
  end

  local filename = vim.fn.expand("%:t")
  local success, err = pcall(function()
    vim.cmd("silent! write")
  end)

  if success then
    vim.notify(filename .. " Saved!")
  else
    vim.notify("Error: " .. err, vim.log.levels.ERROR)
  end
end

vim.api.nvim_set_keymap("n", "<C-s>", ":lua SaveFile()<CR>", { noremap = true, silent = true })

-- Grep selected text (visual mode)
vim.keymap.set("v", "<leader>sg", function()
  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    return
  end

  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  local selected_text = table.concat(lines, "\n")
  selected_text = vim.fn.escape(selected_text, "\\.*[]^$()+?{}")

  if pcall(require, "snacks") then
    require("snacks").picker.grep({ search = selected_text })
  elseif pcall(require, "fzf-lua") then
    require("fzf-lua").live_grep({ search = selected_text })
  else
    vim.notify("No grep picker available", vim.log.levels.ERROR)
  end
end, { desc = "Grep Selected Text" })

-- Grep selected text at root (visual mode)
vim.keymap.set("v", "<leader>sG", function()
  local git_root = vim.fn.system("git rev-parse --show-toplevel 2>/dev/null"):gsub("\n", "")
  local root = vim.v.shell_error == 0 and git_root ~= "" and git_root or vim.fn.getcwd()

  local start_pos = vim.fn.getpos("'<")
  local end_pos = vim.fn.getpos("'>")
  local lines = vim.fn.getline(start_pos[2], end_pos[2])

  if #lines == 0 then
    return
  end

  if #lines == 1 then
    lines[1] = string.sub(lines[1], start_pos[3], end_pos[3])
  else
    lines[1] = string.sub(lines[1], start_pos[3])
    lines[#lines] = string.sub(lines[#lines], 1, end_pos[3])
  end

  local selected_text = table.concat(lines, "\n")
  selected_text = vim.fn.escape(selected_text, "\\.*[]^$()+?{}")

  if pcall(require, "snacks") then
    require("snacks").picker.grep({ search = selected_text, cwd = root })
  elseif pcall(require, "fzf-lua") then
    require("fzf-lua").live_grep({ search = selected_text, cwd = root })
  else
    vim.notify("No grep picker available", vim.log.levels.ERROR)
  end
end, { desc = "Grep Selected Text (Root Dir)" })

-- Delete all marks
vim.keymap.set("n", "<leader>md", function()
  vim.cmd("delmarks!")
  vim.cmd("delmarks A-Z0-9")
  vim.notify("All marks deleted")
end, { desc = "Delete all marks" })

-- Delete all buffers but the current one
vim.keymap.set(
  "n",
  "<leader>bq",
  '<Esc>:%bdelete|edit #|normal`"<Return>',
  { desc = "Delete other buffers but the current one" }
)

-- Delete word in insert mode
vim.keymap.set("i", "<C-b>", "<C-o>de")

-- Escape from all modes
vim.keymap.set({ "i", "n", "v" }, "<C-c>", [[<C-\><C-n>]])

-- Harpoon quick navigation
local function with_harpoon(callback)
  return function()
    local ok, harpoon = pcall(require, "harpoon")
    if not ok then
      vim.notify("Harpoon is not available", vim.log.levels.WARN)
      return
    end
    callback(harpoon)
  end
end

map("n", "<leader>ha", with_harpoon(function(harpoon)
  harpoon:list():add()
end), { desc = "Harpoon add file" })

map("n", "<leader>hh", with_harpoon(function(harpoon)
  harpoon.ui:toggle_quick_menu(harpoon:list())
end), { desc = "Harpoon quick menu" })

for i = 1, 4 do
  map("n", "<leader>h" .. i, with_harpoon(function(harpoon)
    harpoon:list():select(i)
  end), { desc = "Harpoon file " .. i })
end

-- Fast file editing via mini.files; Oil and Neo-tree remain available.
map("n", "<leader>fm", function()
  local ok, mini_files = pcall(require, "mini.files")
  if not ok then
    vim.notify("mini.files is not available", vim.log.levels.WARN)
    return
  end

  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = vim.uv.cwd()
  end
  mini_files.open(path, false)
end, { desc = "Open mini.files" })

-- Convert hex colors on the current line to hsl(...) for theme editing.
map("n", "<leader>uH", function()
  require("config.color_utils").replace_hex_with_hsl_on_line()
end, { desc = "Convert hex to HSL on line" })

-- Disable <A-j>/<A-k> in all modes
vim.api.nvim_set_keymap("i", "<A-j>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("i", "<A-k>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-j>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("n", "<A-k>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<A-j>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "<A-k>", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "J", "<Nop>", { noremap = true, silent = true })
vim.api.nvim_set_keymap("x", "K", "<Nop>", { noremap = true, silent = true })
