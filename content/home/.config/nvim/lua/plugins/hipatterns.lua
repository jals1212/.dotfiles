return {
  {
    "nvim-mini/mini.hipatterns",
    opts = function(_, opts)
      opts.highlighters = opts.highlighters or {}
      opts.highlighters.hsl_color = {
        pattern = "hsl%(%d+,? %d+%%?,? %d+%%?%)",
        group = function(_, match)
          local h, s, l = match:match("hsl%((%d+),? (%d+)%%?,? (%d+)%%?%)")
          local ok, hipatterns = pcall(require, "mini.hipatterns")
          if not ok then
            return nil
          end
          local hex = require("config.color_utils").hsl_to_hex(h, s, l)
          return hipatterns.compute_hex_color_group(hex, "bg")
        end,
      }
    end,
  },
}
