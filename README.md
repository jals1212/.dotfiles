# JALS DOTS

Personal dotfiles deployed with [dotbot] + [dotbot-brew] + [dotbot-mise]. The `./dots` command wraps the lifecycle: install, update, switch theme, doctor, clean, upgrade, uninstall.

Default theme: `kanagawa/dragon`.

[dotbot]: https://github.com/anishathalye/dotbot
[dotbot-brew]: https://github.com/d12frosted/dotbot-brew
[dotbot-mise]: https://github.com/s0cks/dotbot-mise

## Quick Start

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./dots
```

`./dots` is the only entry point you need. On a fresh machine it auto-detects missing prerequisites and bootstraps them (Linux build deps via apt/dnf/pacman, Xcode CLT on macOS, submodule init) before invoking dotbot.

Non-interactive:

```sh
./dots update --yes --theme=kanagawa --flavor=dragon
```

`./dots` is the only entry point. `bootstrap.sh` is removed — no compat alias.

## Lifecycle

| Command | What it does |
|---|---|
| `./dots update [--pull] [--theme=X --flavor=Y] [--yes]` | Runs `./install` (dotbot base config: brew install if missing, `brew bundle`, every symlink, `mise install`) then applies the active theme. With no flags on a TTY, shows `Change theme?` defaulting to No; press Enter to re-apply the manifest theme, or Y to open the pickers. With `--pull`, runs `git pull --ff-only` first. |
| `./dots theme <theme> <flavor>` | Switches the active theme. Re-links the 7 per-app theme files; rewrites the tmux (`@ukiyo-theme`) and Starship (`palette`) fenced lines; rebuilds the bat cache; reloads a running tmux server; writes the slim manifest. |
| `./dots doctor` | Non-mutating: symlink integrity, theme symlink agreement, content markers, slim manifest schema, submodule presence, stale dotbot-backup warning. |
| `./dots clean [--age=N] [--dry-run]` | Removes dead symlinks under managed dirs (via dotbot `--only clean`) and prunes `*.dotbot-backup.*` files older than `N` days (default 30). |
| `./dots upgrade [--commit] [--dry-run]` | Bumps pinned submodule commits, runs `brew bundle cleanup`, `mise prune`. Optionally commits gitlink advances. |
| `./dots uninstall [--yes] [--dry-run]` | Removes declared Dotbot symlinks and `manifest.json`. Preserves `*.dotbot-backup.*` siblings. |
| `./dots` (no args) | TTY: action menu. Non-TTY + manifest absent: auto-runs `update`. Non-TTY + manifest present: errors. |

## Themes

Supported themes:

- `kanagawa`: `dragon`, `lotus`, `wave`
- `catppuccin`: `frappe`, `latte`, `macchiato`, `mocha`

Switch theme:

```sh
./dots theme kanagawa dragon
./dots theme              # interactive picker
./dots theme --current    # show active theme
```

If `@ukiyo-theme` does not refresh in an active tmux session after a switch, run `tmux kill-server` (heavy) or restart tmux manually.

## How it works

- **Symlinks via dotbot**: `install.conf.yaml` declares every base file under `home/` as a `link:` entry. `./install` runs dotbot which creates symlinks in `$HOME`. Edits in `$HOME` write through to the repo via the symlinks.
- **Theme symlinks**: each `content/themes/<theme>-<flavor>.yaml` re-links 7 per-app theme files from `content/assets/palettes/<app>/...` to `$HOME`. Theme switch = retarget those symlinks.
- **Tmux fence**: `home/.config/tmux/tmux.conf` contains a `# >>> dots:theme >>>` / `# <<< dots:theme <<<` block holding the `@ukiyo-theme` line. The theme switcher rewrites between the fences.
- **Starship fence**: `home/.config/starship.toml` is a base symlink holding every theme's `[palettes.<theme>_<flavor>]` table plus a `dots:theme` fence selecting the active `palette`. The theme switcher rewrites that line in place — no per-theme symlink (Starship has no external-theme include).
- **Atuin**: `home/.config/atuin/config.toml` declares static `[theme] name = "dots"`. The atuin theme palette is delivered via the per-theme dotbot symlink `~/.config/atuin/themes/dots.toml`.
- **Manifest**: `manifest.json` (in `.gitignore`) records `{version, theme, flavor, applied_at}`. Local-only state.
- **Brewfile + Mise**: `brew bundle --file=Brewfile` and `mise install` run as dotbot directives during `./install`. Update them via `./dots upgrade`.

## Adding a new theme

1. Add the asset files under `content/assets/palettes/<app>/<theme>/<flavor>.<ext>` for every app.
2. Create `content/themes/<theme>-<flavor>.yaml` mirroring an existing one.
3. Add the pair to `content/themes/index.yaml`.
4. Test with `./dots theme <theme> <flavor>`.

## Adding a mise tool

Edit `home/.config/mise/config.toml`:

```toml
[tools]
node = "lts"
python = "3.12"
```

Run `./dots update` to install. Run `./dots upgrade` to prune removed versions.

## Documentation

- [Install guide](docs/install.md) — install, update, theme, doctor, clean, upgrade, uninstall.
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

MIT © 2026 Jeffrey León ([@jals1212](https://github.com/jals1212)) — see [LICENSE](LICENSE).
