return {
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
