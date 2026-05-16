return {
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts = {
      preset = "classic",
      win = { border = "single" },
    },
    keys = {
      {
        "<leader>?",
        function()
          require("which-key").show({ global = false })
        end,
        desc = "Buffer keymaps",
      },
    },
  },

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

  {
    "b0o/incline.nvim",
    event = "BufReadPre",
    priority = 1200,
    opts = {
      window = { margin = { vertical = 0, horizontal = 1 } },
      hide = { cursorline = true },
      render = function(props)
        local filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(props.buf), ":t")
        if filename == "" then
          filename = "[No Name]"
        end
        if vim.bo[props.buf].modified then
          filename = "[+] " .. filename
        end

        local icon, color = require("nvim-web-devicons").get_icon_color(filename)
        return { { icon or "", guifg = color }, { " " }, { filename } }
      end,
    },
  },

  {
    "folke/zen-mode.nvim",
    cmd = "ZenMode",
    keys = {
      { "<leader>z", "<cmd>ZenMode<CR>", desc = "Zen mode" },
    },
    opts = {
      plugins = {
        gitsigns = true,
        tmux = true,
        kitty = { enabled = false, font = "+2" },
        twilight = { enabled = true },
      },
    },
  },

  {
    "folke/snacks.nvim",
    opts = {
      image = {},
      notifier = {},
      picker = {
        exclude = {
          ".git",
          "node_modules",
        },
        matcher = {
          fuzzy = true,
          smartcase = true,
          ignorecase = true,
          filename_bonus = true,
        },
      },
      dashboard = {
        sections = {
          { section = "header" },
          { icon = " ", title = "Keymaps", section = "keys", indent = 2, padding = 1 },
          { icon = " ", title = "Recent Files", section = "recent_files", indent = 2, padding = 1 },
          { icon = " ", title = "Projects", section = "projects", indent = 2, padding = 1 },
          { section = "startup" },
        },
      },
    },
  },

  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      opts.extensions = opts.extensions or {}
      table.insert(opts.extensions, "quickfix")
      table.insert(opts.extensions, {
        filetypes = { "oil" },
        sections = {
          lualine_a = {
            {
              "mode",
              fmt = function(s)
                local mode_map = {
                  ["NORMAL"] = "N",
                  ["O-PENDING"] = "N?",
                  ["INSERT"] = "I",
                  ["VISUAL"] = "V",
                  ["V-BLOCK"] = "VB",
                  ["V-LINE"] = "VL",
                  ["V-REPLACE"] = "VR",
                  ["REPLACE"] = "R",
                  ["COMMAND"] = "!",
                  ["SHELL"] = "SH",
                  ["TERMINAL"] = "T",
                  ["EX"] = "X",
                  ["S-BLOCK"] = "SB",
                  ["S-LINE"] = "SL",
                  ["SELECT"] = "S",
                  ["CONFIRM"] = "Y?",
                  ["MORE"] = "M",
                }
                return mode_map[s] or s
              end,
            },
          },
          lualine_b = {
            function()
              local ok, oil = pcall(require, "oil")
              if not ok then
                return ""
              end

              local dir = oil.get_current_dir()
              return dir and (vim.fn.fnamemodify(dir, ":~") .. " %m") or ""
            end,
          },
        },
      })
    end,
  },
}
