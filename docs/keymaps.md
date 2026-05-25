# Keymaps

This document lists repo-owned keymaps. LazyVim and plugin defaults can add more mappings; inspect them in Neovim with `:LazyKeys`.

## Policy

- AeroSpace owns the global `ctrl-alt` namespace.
- AeroSpace smart resize is intentionally limited to `ctrl-alt-minus` and `ctrl-alt-equal`.
- `ctrl-alt-r` is kept for AeroSpace `balance-sizes`.
- Ghostty keeps split management on `alt-*` / `ctrl-shift-*` and only unbinds `alt-left/right` so shell/editor navigation can use them.
- Neovim disables `<A-j>` and `<A-k>` in insert/normal/visual modes to avoid accidental conflicts.

## Neovim

### Core navigation

| Key | Mode | Action |
| --- | --- | --- |
| `Ctrl-h/j/k/l` | normal | Move between Neovim windows or tmux panes when available |
| `Ctrl-\` | normal | Move to last active Neovim window or tmux pane |
| `Ctrl-Space` | normal | Move to next Neovim window or tmux pane |
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
| `<leader>ff` | normal | FzfLua find files |
| `<leader>fg` | normal | FzfLua live grep |
| `<leader>fb` | normal | FzfLua buffers |
| `<leader>fh` | normal | FzfLua help tags |
| `<leader>fr` | normal | FzfLua recent files |
| `<leader>fs` | normal/visual | Rip substitute |
| `<leader>fm` | normal | Open mini.files at current buffer/cwd |
| `<leader>sg` | visual | Grep selected text |
| `<leader>sG` | visual | Grep selected text from project root |
| `<leader>gg` | normal | LazyGit |
| `<leader>gb` | normal | Gitsigns blame line |
| `<leader>gd` | normal | Gitsigns diff this |
| `<leader>tt` | normal | Toggle terminal |
| `<leader>bd` | normal | Delete buffer |
| `<leader>bq` | normal | Delete other buffers |
| `<leader>md` | normal | Delete all marks |
| `<leader>ha` | normal | Add current file to Harpoon |
| `<leader>hh` | normal | Open Harpoon quick menu |
| `<leader>h1..h4` | normal | Jump to Harpoon entry 1..4 |
| `<leader>uH` | normal | Convert hex colors on the current line to `hsl(...)` |

### Editor utilities

| Key | Mode | Action |
| --- | --- | --- |
| `gpd` | normal | Preview definition |
| `gpD` | normal | Preview declaration |
| `gpi` | normal | Preview implementation |
| `gpy` | normal | Preview type definition |
| `gpr` | normal | Preview references |
| `gP` | normal | Close preview windows |
| `<leader>cs` | normal | Symbols outline |

### OpenCode

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
| `<leader>?` | Show buffer-local keymaps |
| `<leader>ud` | Toggle docs view |
| `<leader>z` | Toggle Zen Mode |
| `<leader>ut` | Toggle Twilight |
| `<leader>uk` | Toggle Screenkey |

## tmux

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
| `Alt-g` | Toggle scratch session popup (80% × 80%) |
| `Ctrl-a` then `K` | Kill all other sessions after confirm |
| `Ctrl-a` then `T` | Open tmux-ukiyo theme menu |
| `Ctrl-a` then `I` | Install TPM plugins |

### Pane resize

| Key | Action |
| --- | --- |
| `Ctrl-a` then `H` | Resize pane left 5 cells (repeatable) |
| `Ctrl-a` then `J` | Resize pane down 5 cells (repeatable) |
| `Ctrl-a` then `K` | Resize pane up 5 cells (repeatable) |
| `Ctrl-a` then `L` | Resize pane right 5 cells (repeatable) |

### Pane sync

| Key | Action |
| --- | --- |
| `Ctrl-a` then `e` | Toggle synchronize-panes (status bar shows SYNC when on) |

### Layouts

| Key | Action |
| --- | --- |
| `Ctrl-a` then `M-1` | even-horizontal layout |
| `Ctrl-a` then `M-2` | even-vertical layout |
| `Ctrl-a` then `M-3` | main-horizontal layout |
| `Ctrl-a` then `M-4` | main-vertical layout |
| `Ctrl-a` then `M-5` | tiled layout |

### Navigation shortcuts

| Key | Action |
| --- | --- |
| `Ctrl-a` then `Tab` | Jump to last active window |
| `Ctrl-a` then `Backspace` | Jump to last active session |

### fzf pickers

Requires `fzf` on PATH (already in dotfiles stack).

| Key | Action |
| --- | --- |
| `Ctrl-a` then `f` | fzf session picker (80% × 70% popup) |
| `Ctrl-a` then `w` | fzf window picker across all sessions (80% × 70% popup) |

### Status indicators

| Indicator | Condition |
| --- | --- |
| `·PREFIX·` (yellow) | Visible in status-right while prefix key is active |
| `·SYNC·` (red) | Visible in status-right while synchronize-panes is on |

### Breaking changes

- `prefix + L` no longer maps to last-window. Use `prefix + Tab` instead. `prefix + L` now resizes the current pane right by 5 cells.

Copy mode uses vi keys: `v` begins selection, `Ctrl-v` toggles rectangle selection, `y` copies and exits.

## Ghostty

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
