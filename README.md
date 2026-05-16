# dots

Personal dotfiles managed by a Go/Bubble Tea installer.

The repo keeps the installer code under `installer/`, the deployable home payload under `home/`, and reusable theme assets under `assets/themes/`. The default theme selection is `kanagawa/dragon`; non-interactive installs can override it with `DOTS_THEME` and `DOTS_FLAVOR`.

## Quick Start

```bash
make build
./dots              # interactive TUI
./dots install --yes # non-interactive install
```

Useful follow-up commands:

```bash
./dots update      # re-deploy configs only
./dots uninstall   # remove deployed configs
./dots restore --latest # restore newest backup
make test          # Go unit tests
make docker-test   # build the Docker E2E image and run the smoke suite
```

## Documentation

- [Install guide](docs/install.md) — prerequisites, workflows, Docker validation, backups, update/uninstall, and post-install checks.
- [Keymaps](docs/keymaps.md) — repo-owned Neovim, tmux, Ghostty, and AeroSpace shortcuts.
- [Themes](docs/themes.md) — theme families/flavors, asset layout, deploy targets, and maintenance conventions.

## Managed Stack

| Area | Tools / configs | Source |
| --- | --- | --- |
| Installer | Go + Bubble Tea TUI, Docker E2E harness | `installer/` |
| Shell | Zsh, zinit, aliases/functions/keys | `home/.zshrc`, `home/.zalias`, `home/.zfunc`, `home/.zkey` |
| Prompt | Oh My Posh JSON config | `home/.config/oh-my-posh/config.json` |
| Terminal | Ghostty, IosevkaTerm NF, cursor smear shader | `home/.config/ghostty/` |
| Multiplexer | tmux, TPM, tmux-ukiyo, which-key, resurrect/continuum | `home/.config/tmux/tmux.conf` |
| Editor | Neovim + LazyVim + repo overrides | `home/.config/nvim/` |
| AI editor workflow | OpenCode Neovim integration | `home/.config/nvim/lua/plugins/opencode.lua` |
| Window manager | AeroSpace with `ctrl-alt` bindings | `home/.config/aerospace/aerospace.toml` |
| CLI UX | atuin, zoxide, eza, bat, fzf, lazygit, bottom | `home/.config/`, `assets/themes/` |

## Repository Layout

```text
.
├── installer/          # Go installer module
│   ├── cmd/dots/       # CLI/TUI entry point
│   ├── internal/system # OS detection, deploy, filesystem/runner helpers
│   ├── internal/tui    # Bubble Tea screens and install steps
│   ├── e2e/            # Docker E2E test script
│   ├── Dockerfile      # E2E/runtime image used by make docker-test
│   └── go.mod
├── home/               # Managed files copied into $HOME
│   ├── .config/
│   ├── .zshrc
│   ├── .zprofile
│   ├── .zalias
│   ├── .zfunc
│   └── .zkey
├── assets/themes/      # Source theme assets by tool/family/flavor
├── docs/               # User-facing docs
├── Brewfile            # macOS package list
└── Makefile            # build/test/docker entry points
```

## Post-Install

1. Restart the shell: `exec zsh`.
2. Open tmux and install/update plugins if needed: `tmux new -s main`, then `prefix + I` (`prefix` is `Ctrl-a`).
3. Open Neovim; LazyVim plugins install on first launch.
4. Run `make docker-test` before changing installer behavior or deploy assets.

## License

MIT
