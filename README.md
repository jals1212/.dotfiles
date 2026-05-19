# 󰚌 dots

Personal dotfiles managed by a POSIX shell bootstrap and a `dots` dispatcher script.

The repo keeps deployable home payload under `home/`, reusable theme assets under `assets/themes/`, and shell scripts under `lib/` and `commands/`. The default theme selection is `kanagawa/dragon`.

## Quick Start

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

`bootstrap.sh` installs Homebrew (if missing), installs the Brewfile stack, runs the interactive theme/tool wizard, and deploys configs.

Non-interactive (CI or headless):

```sh
./bootstrap.sh --yes --theme=kanagawa --flavor=dragon
```

Supported themes: `kanagawa` (flavors: `wave`, `dragon`, `lotus`), `catppuccin` (flavors: `latte`, `frappe`, `macchiato`, `mocha`).

Useful follow-up commands:

```sh
./dots select      # wizard + full deploy (interactive change)
./dots apply       # non-interactive replay of the deploy pipeline
./dots update      # forced re-deploy from manifest (no backup, no hash check)
./dots sync        # re-deploy only when source hash differs from manifest (--force to override)
./dots doctor      # validate deployed dotfiles locally
./dots restore --latest # restore newest backup
./dots uninstall   # remove deployed configs and manifest.json
make lint          # shellcheck all scripts
make e2e           # Docker E2E smoke suite
```

## Documentation

- [Install guide](docs/install.md) — prerequisites, workflows, Docker validation, backups, update/uninstall, and post-install checks.
- [Keymaps](docs/keymaps.md) — repo-owned Neovim, tmux, Ghostty, and AeroSpace shortcuts.
- [Themes](docs/themes.md) — theme families/flavors, asset layout, deploy targets, and maintenance conventions.

## Managed Stack

| Area | Tools / configs | Source |
| --- | --- | --- |
| Bootstrap | POSIX sh bootstrap + `dots` dispatcher, Docker E2E harness | `bootstrap.sh`, `dots`, `commands/`, `lib/` |
| Shell | Zsh, zinit, aliases/functions/keys | `home/.zshrc`, `home/.zalias`, `home/.zfunc`, `home/.zkey` |
| Prompt | Oh My Posh JSON config | `home/.config/oh-my-posh/config.json` |
| Terminal | Ghostty, IosevkaTerm NF, cursor smear shader | `home/.config/ghostty/` |
| Multiplexer | tmux, TPM, tmux-ukiyo, which-key, resurrect/continuum | `home/.config/tmux/tmux.conf` |
| Editor | Neovim + LazyVim + repo overrides (one plugin per file under `lua/plugins/`; overrides in `overrides.lua`, disables in `disabled.lua`) | `home/.config/nvim/` |
| AI editor workflow | OpenCode Neovim integration | `home/.config/nvim/lua/plugins/opencode.lua` |
| Window manager | AeroSpace with `ctrl-alt` bindings | `home/.config/aerospace/aerospace.toml` |
| CLI UX | atuin, zoxide, eza, bat, fzf, lazygit, bottom | `home/.config/`, `assets/themes/` |

## Repository Layout

```text
.
├── bootstrap.sh        # Entry point: Homebrew + Brewfile + select
├── dots                # Dispatcher: select, apply, update, sync, doctor, restore, uninstall
├── commands/           # Subcommand scripts (POSIX sh)
├── lib/                # Shared library scripts (log, detect, brew, select, deploy, backup, manifest, doctor)
├── home/               # Managed files copied into $HOME
│   ├── .zshrc
│   ├── .zshenv
│   ├── .zprofile
│   └── .config/        # Tool configs (nvim, tmux, ghostty, oh-my-posh,
│                       #   atuin, bat, bottom, eza, fzf, lazygit, zsh/)
├── assets/themes/      # Source theme assets by tool/family/flavor
├── docs/               # User-facing docs
├── Brewfile            # Package list (Homebrew)
└── Makefile            # lint/test/e2e/clean entry points
```

## Post-Install

1. Restart the shell: `exec zsh`.
2. Open tmux and install/update plugins: `tmux new -s main`, then `prefix + I` (`prefix` is `Ctrl-a`).
3. Open Neovim; LazyVim plugins install on first launch.
4. Run `./dots doctor` to validate deployed config files and local smoke checks.
5. Run `make e2e` before changing deploy scripts or theme assets.

## License

MIT
