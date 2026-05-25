return {
  "stevearc/oil.nvim",

  lazy = false,

  keys = {
    { "-", "<CMD>Oil<CR>", desc = "Open Oil (parent dir)" },
    { "<leader>E", "<CMD>Oil --float<CR>", desc = "Open Oil (floating)" },
  },

  opts = {
    default_file_explorer = true,
    restore_win_options = true,
    skip_confirm_for_simple_edits = false,
    prompt_save_on_select_new_entry = true,

    keymaps = {
      ["g?"] = "actions.show_help",
      ["<CR>"] = "actions.select",
      ["<C-s>"] = { "actions.select", opts = { vertical = true }, desc = "Open in vertical split" },
      ["<C-v>"] = { "actions.select", opts = { horizontal = true }, desc = "Open in horizontal split" },
      ["<C-t>"] = { "actions.select", opts = { tab = true }, desc = "Open in new tab" },
      ["<C-p>"] = "actions.preview",
      ["<C-c>"] = "actions.close",
      ["<C-r>"] = "actions.refresh",
      ["-"] = "actions.parent",
      ["_"] = "actions.open_cwd",
      ["`"] = "actions.cd",
      ["~"] = { "actions.cd", opts = { scope = "tab" }, desc = ":tcd to the current oil directory" },
      ["gs"] = "actions.change_sort",
      ["gx"] = "actions.open_external",
      ["g."] = "actions.toggle_hidden",
      ["g\\"] = "actions.toggle_trash",
      ["q"] = "actions.close",
    },

    use_default_keymaps = false,

    view_options = {
      show_hidden = true,
      is_hidden_file = function(name, bufnr)
        return vim.startswith(name, ".")
      end,
      is_always_hidden = function(name, bufnr)
        return name == ".." or name == ".git"
      end,
      natural_order = true,
      case_insensitive = false,
      sort = {
        { "type", "asc" },
        { "name", "asc" },
      },
    },

    float = {
      padding = 2,
      max_width = 100,
      max_height = 30,
      border = "rounded",
      win_options = {
        winblend = 0,
      },
      preview_split = "auto",
      override = function(conf)
        return conf
      end,
    },

    preview = {
      max_width = 0.9,
      min_width = { 40, 0.4 },
      width = nil,
      max_height = 0.9,
      min_height = { 5, 0.1 },
      height = nil,
      border = "rounded",
      win_options = {
        winblend = 0,
      },
      update_on_cursor_moved = true,
    },

    progress = {
      max_width = 0.9,
      min_width = { 40, 0.4 },
      width = nil,
      max_height = { 10, 0.9 },
      min_height = { 5, 0.1 },
      height = nil,
      border = "rounded",
      minimized_border = "none",
      win_options = {
        winblend = 0,
      },
    },

    ssh = {
      border = "rounded",
    },
  },

  dependencies = {
    "nvim-tree/nvim-web-devicons",
  },

  config = function(_, opts)
    require("oil").setup(opts)

    vim.api.nvim_create_autocmd("FileType", {
      pattern = "oil",
      callback = function()
        vim.opt_local.colorcolumn = ""
        vim.opt_local.signcolumn = "no"

        vim.api.nvim_create_autocmd("BufLeave", {
          buffer = 0,
          callback = function()
            if vim.bo.modified then
              vim.cmd("silent! write")
            end
          end,
        })
      end,
    })

    vim.keymap.set("n", "<leader>-", function()
      local oil = require("oil")
      local current_buf = vim.api.nvim_get_current_buf()
      local current_file = vim.api.nvim_buf_get_name(current_buf)

      if current_file and current_file ~= "" then
        local dir = vim.fn.fnamemodify(current_file, ":h")
        oil.open(dir)
      else
        oil.open()
      end
    end, { desc = "Open Oil in current file's directory" })
  end,
}
