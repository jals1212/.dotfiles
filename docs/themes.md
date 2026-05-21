# Themes

Use `./dots theme <theme> <flavor>` to switch. Use `./dots sync` to re-apply the manifest theme.

## Switch theme

Non-interactive:

```sh
./dots theme kanagawa dragon
./dots theme catppuccin mocha
```

Interactive (gum picker):

```sh
./dots theme
```

Show active theme:

```sh
./dots theme --current
```

## What the switcher does

1. Validates `<theme> <flavor>` against `themes/index.yaml` (whitelist).
2. Runs the per-theme dotbot config (`themes/<theme>-<flavor>.yaml`) which re-links 10 per-app theme files from `assets/themes/<app>/...` to `$HOME`.
3. Rewrites the tmux fenced block (`# >>> dots:theme >>>` … `# <<< dots:theme <<<`) in `home/.config/tmux/tmux.conf` so tmux-ukiyo's `@ukiyo-theme` matches the new pair.
4. Runs `bat cache --build` (skipped when bat is absent).
5. If a tmux server is running, runs `tmux source-file ~/.tmux.conf` so the new fenced block takes effect.
6. Writes `manifest.json` atomically: `{ version: "3.0.0", theme, flavor, applied_at }`.

If a running tmux session does not pick up the new theme, run `tmux kill-server` and restart tmux.

## Supported themes

| Theme | Flavors |
| --- | --- |
| `kanagawa` | `dragon`, `lotus`, `wave` |
| `catppuccin` | `frappe`, `latte`, `macchiato`, `mocha` |

Per-flavor accents (Catppuccin/Kanagawa) are baked into each asset variant; there is no separate `--accent` flag.

## What gets themed

| App | Destination | Source |
| --- | --- | --- |
| Oh My Posh | `~/.config/oh-my-posh/config.json` | `assets/themes/oh-my-posh/<theme>/<flavor>.json` |
| bat | `~/.config/bat/themes/dots.tmTheme` | `assets/themes/bat/<theme>/<Titlecase-theme>-<flavor>.tmTheme` |
| eza | `~/.config/eza/themes/dots.sh` | `assets/themes/eza/<theme>/<flavor>.txt` (rename via dotbot) |
| fzf | `~/.config/fzf/themes/dots.sh` | `assets/themes/fzf/<theme>/<flavor>.sh` |
| lazygit | `~/.config/lazygit/config.yml` | `assets/themes/lazygit/<theme>/<flavor>.yml` |
| bottom | `~/.config/bottom/bottom.toml` | `assets/themes/bottom/<theme>/<flavor>.toml` |
| ghostty | `~/.config/ghostty/themes/dots` | `assets/themes/ghostty/<theme>/<flavor>.conf` |
| atuin | `~/.config/atuin/themes/dots.toml` | `assets/themes/atuin/<theme>/<flavor>.toml` (asset declares `name = "dots"`) |
| zsh | `~/.config/dots/theme.sh` | `assets/themes/zsh/<theme>-<flavor>.sh` |
| Neovim | `~/.config/nvim/lua/dots-theme.lua` | `assets/themes/nvim/<theme>-<flavor>.lua` |

Atuin uses a static `[theme] name = "dots"` in `home/.config/atuin/config.toml`; only the `~/.config/atuin/themes/dots.toml` symlink retargets between themes.

tmux is the only app whose shape file (`tmux.conf`) gets a fenced rewrite — the `tmux-ukiyo` plugin reads `@ukiyo-theme` directly and there is no separate-file include path that fits it cleanly.

## Re-apply current theme

```sh
./dots sync
```

`./dots sync` re-runs the dotbot base config and re-applies the manifest theme. No flag changes; if you need to change flag values use `./dots theme <theme> <flavor>` or `./dots update`.

## Check theme health

```sh
./dots doctor
```

Doctor verifies every per-app theme symlink resolves into the repo, the symlinks agree on a single `<theme>/<flavor>` pair, the manifest matches, the atuin static `name = "dots"` is intact, and the tmux fenced block contains exactly one open + one close marker with an `@ukiyo-theme` line between them.
