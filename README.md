# 󰚌 dots

Personal dotfiles with a visual `./dots` command for installing, updating, backing up, restoring, and checking the setup.

Default theme: `kanagawa/dragon`.

## Quick Start

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

Non-interactive:

```sh
./bootstrap.sh --yes --theme=kanagawa --flavor=dragon
```

## Main Commands

```sh
./dots                 # visual menu
./dots update          # change theme/tools and apply
./dots sync            # re-apply current config
./dots sync --force    # force re-apply
./dots backup          # create a backup
./dots restore         # visually choose a backup, newest first
./dots restore --latest # restore newest backup directly
./dots doctor          # health check
./dots uninstall       # remove managed configs
```

First run: if no config exists yet, `./dots` starts `update` automatically.

## Themes

Supported themes:

- `kanagawa`: `dragon`, `lotus`, `wave`
- `catppuccin`: `latte`, `frappe`, `macchiato`, `mocha`

Change theme:

```sh
./dots update
```

## Documentation

- [Install guide](docs/install.md) — install, update, sync, backup, restore, doctor, uninstall.
- [Tools](docs/tools.md) — common usage for managed CLI tools.
- [Aliases](docs/aliases.md) — shell aliases and functions.
- [Plugins](docs/plugins.md) — zsh/tmux plugin usage.
- [Keymaps](docs/keymaps.md) — Neovim, tmux, Ghostty, AeroSpace shortcuts.
- [Themes](docs/themes.md) — theme switching and supported flavors.

## After Install

```sh
exec zsh
./dots doctor
```

Then open tmux and press `Ctrl-a I` to install tmux plugins.

## License

MIT
