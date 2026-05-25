-- Repo-owned color utilities adapted from the Gentleman.Dots helper module.
-- Kept intentionally dependency-free so editor helpers can use it during startup.

local M = {}

local function clamp(value, min, max)
  return math.max(min, math.min(max, value))
end

function M.hex_to_rgb(hex)
  hex = tostring(hex):gsub("#", "")
  if #hex == 3 then
    hex = hex:gsub("(.)", "%1%1")
  end
  if #hex ~= 6 or not hex:match("^[0-9a-fA-F]+$") then
    return nil
  end

  return tonumber(hex:sub(1, 2), 16), tonumber(hex:sub(3, 4), 16), tonumber(hex:sub(5, 6), 16)
end

function M.rgb_to_hsl(r, g, b)
  r, g, b = r / 255, g / 255, b / 255
  local max, min = math.max(r, g, b), math.min(r, g, b)
  local h, s = 0, 0
  local l = (max + min) / 2

  if max ~= min then
    local d = max - min
    s = l > 0.5 and d / (2 - max - min) or d / (max + min)
    if max == r then
      h = (g - b) / d + (g < b and 6 or 0)
    elseif max == g then
      h = (b - r) / d + 2
    else
      h = (r - g) / d + 4
    end
    h = h / 6
  end

  return math.floor(h * 360 + 0.5), math.floor(s * 100 + 0.5), math.floor(l * 100 + 0.5)
end

local function hue_to_rgb(p, q, t)
  if t < 0 then
    t = t + 1
  end
  if t > 1 then
    t = t - 1
  end
  if t < 1 / 6 then
    return p + (q - p) * 6 * t
  end
  if t < 1 / 2 then
    return q
  end
  if t < 2 / 3 then
    return p + (q - p) * (2 / 3 - t) * 6
  end
  return p
end

function M.hsl_to_rgb(h, s, l)
  h = (tonumber(h) or 0) / 360
  s = clamp((tonumber(s) or 0) / 100, 0, 1)
  l = clamp((tonumber(l) or 0) / 100, 0, 1)

  if s == 0 then
    local gray = math.floor(l * 255 + 0.5)
    return gray, gray, gray
  end

  local q = l < 0.5 and l * (1 + s) or l + s - l * s
  local p = 2 * l - q
  return math.floor(hue_to_rgb(p, q, h + 1 / 3) * 255 + 0.5),
    math.floor(hue_to_rgb(p, q, h) * 255 + 0.5),
    math.floor(hue_to_rgb(p, q, h - 1 / 3) * 255 + 0.5)
end

function M.hsl_to_hex(h, s, l)
  local r, g, b = M.hsl_to_rgb(h, s, l)
  return string.format("#%02x%02x%02x", r, g, b)
end

function M.hex_to_hsl_string(hex)
  local r, g, b = M.hex_to_rgb(hex)
  if not r then
    return nil
  end
  local h, s, l = M.rgb_to_hsl(r, g, b)
  return string.format("hsl(%d, %d, %d)", h, s, l)
end

function M.replace_hex_with_hsl_on_line()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local line = vim.api.nvim_buf_get_lines(0, row - 1, row, false)[1] or ""
  local changed = line:gsub("#[0-9a-fA-F][0-9a-fA-F][0-9a-fA-F][0-9a-fA-F]?[0-9a-fA-F]?[0-9a-fA-F]?", function(hex)
    return M.hex_to_hsl_string(hex) or hex
  end)

  if changed ~= line then
    vim.api.nvim_buf_set_lines(0, row - 1, row, false, { changed })
  end
end

return M
