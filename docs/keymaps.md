# Keymaps

This document lists repo-owned keymaps. LazyVim and plugin defaults can add more mappings; inspect them in Neovim with `:LazyKeys`.

## Policy

- AeroSpace owns the global `ctrl-alt` namespace.
- AeroSpace smart resize is intentionally limited to `ctrl-alt-minus` and `ctrl-alt-equal`.
- `ctrl-alt-r` is kept for AeroSpace `balance-sizes`.
- Ghostty keeps split management on `alt-*` / `ctrl-shift-*` and only unbinds `alt-left/right` so shell/editor navigation can use them.
- Neovim disables `<A-j>` and `<A-k>` in insert/normal/visual modes to avoid accidental conflicts.

## Neovim

Source: `home/.config/nvim/lua/config/keymaps.lua` plus plugin files under `home/.config/nvim/lua/plugins/`.

### Core navigation

| Key | Mode | Action |
| --- | --- | --- |
| `Ctrl-h/j/k/l` | normal | Move between windows |
| `Ctrl-Up/Down` | normal | Increase/decrease window height |
| `Ctrl-Left/Right` | normal | Decrease/increase window width |
| `Shift-h/l` | normal | Previous/next buffer |
| `Ctrl-s` | normal | Save current file with notification |
| `Ctrl-c` | insert/normal/visual | Escape to normal terminal state |
| `Esc` | normal | Clear search highlight |
| `Ctrl-b` | insert | Delete word |

### Files, search, git, terminal

| Key | Mode | Action |
| --- | --- | --- |
| `<leader>e` | normal | Toggle Neo-tree |
| `-` | normal | Open Oil parent directory |
| `<leader>E` | normal | Open Oil floating window |
| `<leader>-` | normal | Open Oil in current file directory |
| `<leader>ff` | normal | Telescope find files |
| `<leader>fg` | normal | Telescope live grep |
| `<leader>fb` | normal | Telescope buffers |
| `<leader>fh` | normal | Telescope help tags |
| `<leader>fr` | normal | Telescope recent files |
| `<leader>sg` | visual | Grep selected text |
| `<leader>sG` | visual | Grep selected text from project root |
| `<leader>gg` | normal | LazyGit |
| `<leader>gb` | normal | Gitsigns blame line |
| `<leader>gd` | normal | Gitsigns diff this |
| `<leader>tt` | normal | Toggle terminal |
| `<leader>bd` | normal | Delete buffer |
| `<leader>bq` | normal | Delete other buffers |
| `<leader>md` | normal | Delete all marks |

### OpenCode

Source: `home/.config/nvim/lua/plugins/opencode.lua`.

| Key | Mode | Action |
| --- | --- | --- |
| `<leader>aa` | normal | Toggle OpenCode |
| `<leader>as` | normal/visual | Submit selected context |
| `<leader>ai` | normal/visual | Ask OpenCode |
| `<leader>aI` | normal/visual | Ask with `@this` context |
| `<leader>ab` | normal/visual | Ask about current buffer |
| `<leader>ap` | normal/visual | Prompt with `@this` |
| `<leader>ape` | normal/visual | Explain |
| `<leader>apf` | normal/visual | Fix |
| `<leader>apd` | normal/visual | Diagnose |
| `<leader>apr` | normal/visual | Review |
| `<leader>apt` | normal/visual | Test |
| `<leader>apo` | normal/visual | Optimize |

### DAP

Source: `home/.config/nvim/lua/plugins/nvim-dap.lua`.

| Key | Action |
| --- | --- |
| `<leader>db` | Toggle breakpoint |
| `<leader>dB` | Conditional breakpoint |
| `<leader>dc` | Continue |
| `<leader>da` | Run with args |
| `<leader>dC` | Run to cursor |
| `<leader>dg` | Go to line without executing |
| `<leader>di` | Step into |
| `<leader>dO` | Step over |
| `<leader>do` | Step out |
| `<leader>dp` | Pause |
| `<leader>dr` | Toggle REPL |
| `<leader>dl` | Run last |
| `<leader>dt` | Terminate |
| `<leader>dw` | Widgets hover |

### UI utilities

| Key | Action |
| --- | --- |
| `<leader>ut` | Toggle Twilight |
| `<leader>uk` | Toggle Screenkey |

## tmux

Source: `home/.config/tmux/tmux.conf`.

Prefix is `Ctrl-a`.

| Key | Action |
| --- | --- |
| `Ctrl-a` then `r` | Reload tmux config |
| `Ctrl-a` then `h/j/k/l` | Select pane left/down/up/right |
| `Alt-Left/Right/Up/Down` | Select pane by direction |
| `Shift-Left/Right` | Previous/next window |
| `Alt-H/L` | Previous/next window |
| `Ctrl-a` then `v` or `|` | Horizontal split in current path |
| `Ctrl-a` then `d` or `-` | Vertical split in current path |
| `Ctrl-a` then `c` | New window in current path |
| `Alt-g` | Toggle scratch session popup |
| `Ctrl-a` then `K` | Kill all other sessions after confirm |
| `Ctrl-a` then `T` | Open tmux-ukiyo theme menu |
| `Ctrl-a` then `I` | Install TPM plugins |

Copy mode uses vi keys: `v` begins selection, `Ctrl-v` toggles rectangle selection, `y` copies and exits.

## Ghostty

Source: `home/.config/ghostty/config`.

| Key | Action |
| --- | --- |
| `Alt-v` | New split right |
| `Alt-d` | New split down |
| `Alt-h/j/k/l` | Focus split left/down/up/right |
| `Ctrl-Shift-h/j/k/l` | Resize split left/up/down/right as configured |
| `Cmd-k` | Clear screen |
| `Shift-Enter` | Send escaped newline |
| `Alt-s` | Write screen file to paste |

## AeroSpace

Source: `home/.config/aerospace/aerospace.toml`.

### Layout and focus

| Key | Action |
| --- | --- |
| `ctrl-alt-/` | Cycle tiles layout orientation |
| `ctrl-alt-,` | Cycle accordion layout orientation |
| `ctrl-alt-h/j/k/l` | Focus left/down/up/right |
| `ctrl-alt-shift-h/j/k/l` | Move window left/down/up/right |
| `ctrl-alt-minus` | Smart resize `-50` |
| `ctrl-alt-equal` | Smart resize `+50` |
| `ctrl-alt-r` | Balance sizes |

### Workspaces

| Key | Action |
| --- | --- |
| `ctrl-alt-1..9` | Switch to workspace `1..9` |
| `ctrl-alt-q/w/e` | Switch to workspace `Q/W/E` |
| `ctrl-alt-a/s/d` | Switch to workspace `A/S/D` |
| `ctrl-alt-z/x/c` | Switch to workspace `Z/X/C` |
| `ctrl-alt-shift-<workspace>` | Move focused window to workspace |
| `ctrl-alt-tab` | Workspace back and forth |
| `ctrl-alt-shift-tab` | Move workspace to next monitor |

### Service mode

| Key | Action |
| --- | --- |
| `ctrl-alt-shift-;` | Enter service mode |
| `Esc` | Reload config and return to main mode |
| `r` | Flatten workspace tree and return |
| `f` | Toggle floating/tiling and return |
| `Backspace` | Close all windows except current and return |
| `ctrl-alt-shift-h/j/k/l` | Join with direction and return |
