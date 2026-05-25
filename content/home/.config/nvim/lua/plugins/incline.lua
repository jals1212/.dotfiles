return {
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
        return { { icon or "", guifg = color }, { " " }, { filename } }
      end,
    },
  },
}
