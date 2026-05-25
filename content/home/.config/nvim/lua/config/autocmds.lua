-- Quality-of-life autocmds. All registered under a single augroup so they
-- are idempotent on reload (clear = true wipes previous registrations).
local augroup = vim.api.nvim_create_augroup("dots_autocmds", { clear = true })

-- 1. Briefly highlight yanked text.
vim.api.nvim_create_autocmd("TextYankPost", {
  group = augroup,
  callback = function()
    vim.hl.on_yank({ timeout = 200 })
  end,
})

-- 2. Restore cursor to its last valid position when reopening a file.
vim.api.nvim_create_autocmd("BufReadPost", {
  group = augroup,
  callback = function()
    local mark = vim.api.nvim_buf_get_mark(0, '"')
    local lcount = vim.api.nvim_buf_line_count(0)
    if mark[1] > 0 and mark[1] <= lcount then
      pcall(vim.api.nvim_win_set_cursor, 0, mark)
    end
  end,
})

-- 3. Map q → close for read-only / ephemeral buffer types.
vim.api.nvim_create_autocmd("FileType", {
  group = augroup,
  pattern = { "help", "man", "qf", "lspinfo", "checkhealth", "startuptime", "PlenaryTestPopup" },
  callback = function(event)
    vim.bo[event.buf].buflisted = false
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = event.buf, silent = true })
  end,
})

-- 4. Terminal buffers: no line numbers, start in insert mode.
vim.api.nvim_create_autocmd("TermOpen", {
  group = augroup,
  callback = function()
    vim.opt_local.number = false
    vim.opt_local.relativenumber = false
    vim.cmd("startinsert")
  end,
})

-- 5. Treat .env* and *.env files as sh for syntax highlighting.
vim.api.nvim_create_autocmd({ "BufRead", "BufNewFile" }, {
  group = augroup,
  pattern = { ".env*", "*.env" },
  callback = function()
    vim.bo.filetype = "sh"
  end,
})
