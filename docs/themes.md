# Themes

Use `./dots theme <theme> <flavor>` to switch. Use `./dots update` and press Enter at `Change theme?` to re-apply the manifest theme.

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
2. Runs the per-theme dotbot config (`content/themes/<theme>-<flavor>.yaml`) which re-links 7 per-app theme files from `content/assets/palettes/<app>/...` to `$HOME`.
3. Rewrites the `# >>> dots:theme >>>` … `# <<< dots:theme <<<` fenced block in two files: `home/.config/tmux/tmux.conf` (sets tmux-ukiyo's `@ukiyo-theme`) and `home/.config/starship.toml` (sets Starship's active `palette`).
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
| bat | `~/.config/bat/themes/dots.tmTheme` | `assets/themes/bat/<theme>/<Titlecase-theme>-<flavor>.tmTheme` |
| eza | `~/.config/eza/themes/dots.sh` | `assets/themes/eza/<theme>/<flavor>.txt` (rename via dotbot) |
| fzf | `~/.config/fzf/themes/dots.sh` | `assets/themes/fzf/<theme>/<flavor>.sh` |
| lazygit | `~/.config/lazygit/config.yml` | `assets/themes/lazygit/<theme>/<flavor>.yml` |
| bottom | `~/.config/bottom/bottom.toml` | `assets/themes/bottom/<theme>/<flavor>.toml` |
| ghostty | `~/.config/ghostty/themes/dots` | `assets/themes/ghostty/<theme>/<flavor>.conf` |
| Neovim | Reads `manifest.json` | `content/assets/palettes/nvim/<theme>-<flavor>.lua` |


Neovim reads the active theme from `manifest.json`; there is no mutable `~/.config/nvim/lua/dots-theme.lua` symlink.

tmux and Starship are the two apps themed by a fenced rewrite instead of a per-theme symlink: `tmux.conf`'s `@ukiyo-theme` and `starship.toml`'s active `palette` are rewritten in place inside their `# >>> dots:theme >>>` … `# <<< dots:theme <<<` blocks. Starship has no external-theme include (unlike ghostty), so all of its per-theme palettes live in the one `starship.toml` and only the active `palette` line changes.

## Re-apply current theme

```sh
./dots update
# Press Enter at: Change theme?
```

`./dots update` re-runs the dotbot base config and re-applies the manifest theme when you keep the default No answer at `Change theme?`. If you need to change theme values, answer Y to open the picker or use `./dots theme <theme> <flavor>`.

## Check theme health

```sh
./dots doctor
```

Doctor verifies every per-app theme symlink resolves into the repo, the symlinks agree on a single `<theme>/<flavor>` pair, the manifest matches, Neovim's manifest-driven theme helper is readable, the tmux fenced block contains exactly one open + one close marker with an `@ukiyo-theme` line between them, and `starship.toml` carries exactly one dots:theme fence with an active `palette` line.
