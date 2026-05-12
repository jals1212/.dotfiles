# dots

Personal dotfiles managed by a Go TUI installer.

## Quick Start

```bash
# Build
make build

# Run interactive installer
./dots

# Non-interactive (install everything)
./dots --yes
```

## What's Included

| Tool | Config | Theme |
|------|--------|-------|
| Ghostty | `configs/ghostty/` | Catppuccin Mocha |
| Tmux | `configs/tmux/` | Catppuccin Mocha (via catppuccin/tmux) |
| Neovim | `configs/nvim/` | Catppuccin Mocha (LazyVim) |
| Starship | `configs/starship/` | Catppuccin Mocha palette |
| ZSH | `configs/zsh/` | Starship prompt |
| Atuin | `configs/atuin/` | Catppuccin Mocha |

## Tools

- **Ghostty** — Terminal emulator with IosevkaTerm NF font
- **Tmux** — Multiplexer with TPM, vim-tmux-navigator, resurrect
- **Neovim** — LazyVim with LSP, TreeSitter, autocompletion
- **Starship** — Fast custom prompt
- **Atuin** — Enhanced shell history
- **Zoxide** — Smart directory jumping
- **Mise** — Language runtime manager (replaces asdf)
- **eza** — Modern `ls` replacement
- **bat** — Modern `cat` replacement
- **ripgrep** — Fast search
- **fd** — Modern `find`
- **lazygit** — Terminal Git UI
- **bottom** — System monitor
- **dust** — Disk usage analyzer

## Post-Install

1. Restart shell: `exec zsh`
2. Open tmux: `tmux new -s main` then press `C-a I` to install plugins
3. Open nvim — plugins install automatically on first launch

## Structure

```
~/.dotfiles/
├── cmd/dots/           # TUI installer entry point
├── internal/
│   ├── system/         # OS detect, packages, deploy engine
│   └── tui/            # Bubbletea TUI screens
├── configs/            # All managed dotfiles
│   ├── ghostty/
│   ├── tmux/
│   ├── nvim/
│   ├── starship/
│   ├── atuin/
│   └── zsh/
├── Makefile
├── Brewfile
└── go.mod
```

## License

MIT
