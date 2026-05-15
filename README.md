# dots

Personal dotfiles managed by a Go TUI installer.

## Quick Start

```bash
# Build
make build

# Run interactive installer
./dots

# Non-interactive (install everything)
./dots install --yes
```

## What's Included

| Tool | Config | Theme |
|------|--------|-------|
| Ghostty | `home/.config/ghostty/` | Catppuccin/Kanagawa |
| Tmux | `home/.config/tmux/` | tmux-ukiyo |
| Neovim | `home/.config/nvim/` | LazyVim |
| Oh My Posh | `home/.config/oh-my-posh/` | Catppuccin/Kanagawa |
| ZSH | `home/.zshrc` | Oh My Posh prompt |
| Atuin | `home/.config/atuin/` | Catppuccin/Kanagawa |

## Tools

- **Ghostty** — Terminal emulator with IosevkaTerm NF font
- **Tmux** — Multiplexer with TPM, vim-tmux-navigator, resurrect
- **Neovim** — LazyVim with LSP, TreeSitter, autocompletion
- **Oh My Posh** — Fast custom prompt
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
├── installer/          # Go installer module
│   ├── cmd/dots/       # TUI installer entry point
│   ├── internal/
│   │   ├── system/     # OS detect, packages, deploy engine
│   │   └── tui/        # Bubbletea TUI screens
│   ├── e2e/            # Docker E2E harness
│   ├── Dockerfile
│   ├── go.mod
│   └── go.sum
├── home/               # Managed dotfiles payload
│   ├── .config/
│   ├── .zshrc
│   ├── .zprofile
│   ├── .zalias
│   ├── .zfunc
│   └── .zkey
├── assets/             # Theme assets
├── Makefile
└── Brewfile
```

## License

MIT
