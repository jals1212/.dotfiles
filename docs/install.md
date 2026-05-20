# Install Guide

## Requirements

- macOS: `curl`
- Linux: `curl`, `git`, and `sudo`

No Go or Docker is required for normal use.

## First install

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

What to expect:

1. Required packages are installed.
2. The `update` flow opens so you can choose theme/tools.
3. Your config is deployed.
4. A backup is created before deployment when existing managed files are present.

## Non-interactive install

```sh
./bootstrap.sh --yes --theme=kanagawa --flavor=dragon
```

Supported flags:

```sh
--yes
--theme=kanagawa|catppuccin
--flavor=dragon|wave|lotus|latte|frappe|macchiato|mocha
--accent=mauve|blue|green|peach|pink|red|yellow
--tools=zsh,tmux,nvim,ghostty,oh-my-posh,atuin,zoxide
```

## Everyday commands

Run `./dots` for the visual menu. On first run, if no config has been applied yet, `./dots` starts `update` automatically.

| Command | Use when you want to... |
| --- | --- |
| `./dots` | Open the visual action menu. |
| `./dots update` | Change theme/tools and apply immediately. |
| `./dots sync` | Re-apply the current config. |
| `./dots sync --force` | Re-apply even when nothing appears to have changed. |
| `./dots backup` | Create a backup now. |
| `./dots restore` | Pick a backup visually, newest first. |
| `./dots restore --latest` | Restore the newest backup directly. |
| `./dots restore PATH` | Restore a specific backup. |
| `./dots doctor` | Check whether the install looks healthy. |
| `./dots uninstall` | Remove managed config files. |

In scripts or CI, use an explicit subcommand such as `./dots sync`; the initialized no-argument menu is interactive-only.

## Themes

Supported themes:

| Theme | Flavors |
| --- | --- |
| `kanagawa` | `dragon`, `lotus`, `wave` |
| `catppuccin` | `latte`, `frappe`, `macchiato`, `mocha` |

Change theme interactively:

```sh
./dots update
```

Change theme non-interactively:

```sh
./dots update --yes --theme=catppuccin --flavor=mocha --accent=mauve
```

## Backup and restore

Create a backup:

```sh
./dots backup
```

Restore visually:

```sh
./dots restore
```

Restore the newest backup without the picker:

```sh
./dots restore --latest
```

Restore a specific backup:

```sh
./dots restore .backups/2026-05-19T12-00-00Z
```

## Health check

After install or updates:

```sh
./dots doctor
```

If doctor reports a problem, try:

```sh
./dots sync --force
./dots doctor
```

## Post-install

```sh
exec zsh
./dots doctor
```

Then:

1. Open tmux and install plugins with `Ctrl-a I`.
2. Open Neovim; plugins install on first launch.
