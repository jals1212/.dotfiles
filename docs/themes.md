# Themes

Use `./dots theme <theme> <flavor>` to switch. Use `./dots update` and press Enter at `Change theme?` to re-apply the manifest theme.

## Switch theme

Non-interactive:

```sh
./dots theme kanagawa dragon
./dots theme catppuccin mocha
```

Interactive picker (own key reader: ↑↓/jk move, enter select, q/esc cancel):

```sh
./dots theme
```

Show active theme:

```sh
./dots theme --current
```

## What the switcher does

1. Validates `<theme> <flavor>` against `themes/index.yaml` (whitelist).
2. Runs the per-theme dotbot config (`content/themes/<theme>-<flavor>.yaml`) which re-links 6 per-app theme files from `content/assets/palettes/<app>/...` to `$HOME`.
3. Points `content/home/.config/nvim/lua/dots-theme.lua` at `content/assets/palettes/nvim/<theme>-<flavor>.lua` (see [Neovim](#neovim)); a missing palette or a real file in that spot aborts the switch before the manifest is written.
4. Rewrites fenced theme blocks in `content/home/.config/starship.toml` (`palette`) and `content/home/.config/herdr/config.toml` (`theme.name`), then persists `DOTS_THEME=<theme>_<flavor>` in `~/.config/zsh/local.zsh` — machine-local state read by tmux's `@themux_theme` and the p10k palette.
5. Runs `bat cache --build` (skipped when bat is absent).
6. If a tmux server is running, pushes the new `DOTS_THEME` into its global environment (`tmux set-environment -g`) and re-sources the config so themux picks it up.
7. If a Herdr server is running, asks it to reload `config.toml`.
8. Writes `manifest.json` atomically: `{ version, theme, flavor, prompt, applied_at }`.

Theme switches apply to running tmux servers without restarts: `theme.conf` starts with themux's reset (`themux_reset.conf`), which wipes all theme-derived state before the config rebuilds it.

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
| eza | `~/.config/eza/theme.sh` | `assets/themes/eza/<theme>/<flavor>.txt` (rename via dotbot) |
| fzf | `~/.config/fzf/theme.sh` | `assets/themes/fzf/<theme>/<flavor>.sh` |
| lazygit | `~/.config/lazygit/config.yml` | `assets/themes/lazygit/<theme>/<flavor>.yml` |
| bottom | `~/.config/bottom/bottom.toml` | `assets/themes/bottom/<theme>/<flavor>.toml` |
| ghostty | `~/.config/ghostty/themes/dots` | `assets/themes/ghostty/<theme>/<flavor>.conf` |
| Neovim | `content/home/.config/nvim/lua/dots-theme.lua` (repo-side, gitignored; reached as `~/.config/nvim/lua/dots-theme.lua` through the linked `lua/` dir) | `content/assets/palettes/nvim/<theme>-<flavor>.lua` |
| Herdr | `~/.config/herdr/config.toml` fenced `theme.name` | Built-in Herdr theme (`kanagawa`, `kanagawa-lotus`, `catppuccin`, or `catppuccin-latte`) |

### Neovim

Neovim follows the active dots theme through `lua/dots-theme.lua`, a symlink to the flavor's palette (`{ theme, flavor, plugin, colorscheme }`). Because `~/.config/nvim/lua` is itself a link into `content/home/.config/nvim/lua`, the switcher creates the link inside the repo (it is gitignored, so no dotbot entry and no repo diff). `lua/config/theme.lua` reads it (falling back to `kanagawa-wave` when the link is missing or broken), and `lua/plugins/colorscheme.lua` declares `rebelot/kanagawa.nvim` and `catppuccin/nvim` and sets LazyVim's `colorscheme` from it.

A running Neovim re-reads the link on `FocusGained` and switches colorscheme in place. Switching theme family needs the other plugin installed: the first launch after this change (or `:Lazy sync`) installs `kanagawa.nvim` and updates `lazy-lock.json`; until then Neovim falls back to `habamax`.

Starship uses a fenced rewrite instead of a per-theme symlink: `starship.toml`'s active `palette` line is rewritten in place inside its `# >>> dots:theme >>>` … `# <<< dots:theme <<<` block. Starship has no external-theme include (unlike ghostty), so all of its per-theme palettes live in the one `starship.toml` and only the active `palette` line changes.

Herdr is also themed by a fenced rewrite. Dots maps `kanagawa/lotus` to Herdr's `kanagawa-lotus`, the other Kanagawa flavors to `kanagawa`, `catppuccin/latte` to `catppuccin-latte`, and the other Catppuccin flavors to `catppuccin`. `auto_switch = false` stays in config so the dots-selected theme remains authoritative.

tmux needs neither a symlink nor a fence: `theme.conf` (sourced from `tmux.conf`) sets themux's `@themux_theme` from the `DOTS_THEME` environment variable (whose `theme_flavor` values match themux theme names), with a tracked default for servers started without it. The switcher refreshes a running server's environment and re-sources the config, so the repo file never changes.

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

Doctor verifies every per-app theme symlink resolves into the repo, the symlinks agree on a single `<theme>/<flavor>` pair, the manifest matches, Neovim's `dots-theme.lua` link points at the manifest theme/flavor palette, `theme.conf` sets `@themux_theme` from `DOTS_THEME` and carries a default fallback, and Starship/Herdr each carry exactly one dots:theme fence with an active theme line.
