-- Stable Node.js host selection for Node-backed Neovim plugins.
--
-- Prefer system/global Node.js paths over project-local shims so opening older
-- projects does not force Neovim providers onto unsupported Node versions.

local M = {}

local function expand_glob(pattern)
  local matches = vim.fn.glob(pattern, false, true)
  table.sort(matches, function(a, b)
    return a > b
  end)
  return matches[1]
end

local function candidate_paths()
  return {
    "/opt/homebrew/bin/node",
    "/usr/local/bin/node",
    vim.fn.expand("~/.volta/bin/node"),
    expand_glob(vim.fn.expand("~/.nvm/versions/node/*/bin/node")),
    vim.fn.expand("~/.nix-profile/bin/node"),
    "/usr/bin/node",
    vim.fn.exepath("node"),
  }
end

local function node_version(path)
  if not path or path == "" or vim.fn.executable(path) ~= 1 then
    return nil
  end

  local output = vim.fn.system({ path, "--version" })
  if vim.v.shell_error ~= 0 then
    return nil
  end

  return output:gsub("\r", ""):gsub("\n", ""):gsub("^v", "")
end

local function major(version)
  if not version then
    return nil
  end
  return tonumber(version:match("^(%d+)"))
end

local function detect_source(path)
  if path:match("%.volta/") then
    return "Volta"
  elseif path:match("%.nvm/") then
    return "NVM"
  elseif path:match("%.nix%-profile/") then
    return "Nix"
  elseif path:match("homebrew") then
    return "Homebrew"
  end
  return "System"
end

function M.setup(opts)
  opts = opts or {}

  for _, path in ipairs(candidate_paths()) do
    local version = node_version(path)
    if version then
      vim.g.node_host_prog = path

      local npm = vim.fn.exepath("npm")
      if npm ~= "" then
        vim.g.npm_host_prog = npm
      end

      if not opts.silent and (major(version) or 0) < 18 then
        vim.notify(
          "Node.js " .. version .. " is configured for Neovim, but v18+ is recommended.",
          vim.log.levels.WARN
        )
      end

      return true
    end
  end

  if not opts.silent then
    vim.notify("Node.js was not found; Node-backed Neovim providers may be unavailable.", vim.log.levels.WARN)
  end
  return false
end

function M.info()
  if not vim.g.node_host_prog then
    print("Node.js: not configured")
    return
  end

  local version = node_version(vim.g.node_host_prog) or "unknown"
  print("Node.js for Neovim: " .. vim.g.node_host_prog .. " (v" .. version .. ")")
  print("Source: " .. detect_source(vim.g.node_host_prog))
  if vim.g.npm_host_prog then
    print("npm: " .. vim.g.npm_host_prog)
  end
end

vim.api.nvim_create_user_command("NodeRefresh", function()
  M.setup({ silent = false })
  M.info()
end, { desc = "Refresh Neovim Node.js host" })

vim.api.nvim_create_user_command("NodeInfo", function()
  M.info()
end, { desc = "Show Neovim Node.js host" })

return M
