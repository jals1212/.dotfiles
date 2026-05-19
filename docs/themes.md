# Themes

Themes are deployed from source assets in `assets/themes/` and written into managed configs under `home/` by `./dots apply`.

## Defaults

- Default family: `kanagawa`
- Default flavor: `dragon`
- Non-interactive override: `./bootstrap.sh --yes --theme=<family> --flavor=<flavor>`

## Supported families and flavors

| Family | Flavors |
| --- | --- |
| `kanagawa` | `dragon`, `lotus`, `wave` |
| `catppuccin` | `latte`, `frappe`, `macchiato`, `mocha` |

## Asset layout

```text
assets/themes/
├── atuin/<family>/<flavor>.toml
├── bat/<family>/<Theme-flavor>.tmTheme
├── bottom/<family>/<flavor>.toml
├── eza/<family>/<flavor>.txt
├── fzf/<family>/<flavor>.sh
├── ghostty/<family>/<flavor>.conf
├── lazygit/<family>/<flavor>.yml
└── oh-my-posh/<family>/<flavor>.json
```

Kanagawa filenames sometimes include the upstream family prefix for a tool, for example `assets/themes/atuin/kanagawa/kanagawa-dragon.toml` and `assets/themes/bat/kanagawa/Kanagawa-dragon.tmTheme`.

## Deployed targets

| Tool | Deployed target / behavior |
| --- | --- |
| Oh My Posh | Copies JSON theme to `~/.config/oh-my-posh/config.json` |
| Atuin | Copies theme to `~/.config/atuin/themes/` and keeps config in `~/.config/atuin/config.toml` |
| bottom | Writes `~/.config/bottom/bottom.toml` |
| lazygit | Writes `~/.config/lazygit/config.yml` |
| bat | Copies `.tmTheme` to `~/.config/bat/themes/dots.tmTheme` and exports `BAT_THEME=dots` in `.zshrc` |
| eza | Writes color shell snippet to `~/.config/eza/themes/dots.sh`; sourced from `.zshrc` |
| fzf | Writes color shell snippet to `~/.config/fzf/themes/dots.sh`; sourced from `.zshrc` |
| Ghostty | Replaces the managed theme block in `~/.config/ghostty/config` |
| tmux | Uses `DOTS_THEME_FLAVOR` placeholder for tmux-ukiyo (`family/flavor`) |
| Neovim | Uses the selected theme/flavor through managed config placeholders and plugin config |

## Placeholders and marker blocks

Deploy code replaces these placeholders where present:

- `DOTS_THEME_FLAVOR` → `<family>/<flavor>`
- `DOTS_THEME` → `<family>`
- `DOTS_FLAVOR` → `<flavor>`

Shell and terminal theme snippets are updated between marker blocks such as:

- `CATPPUCCIN_BAT_START` / `CATPPUCCIN_BAT_END`
- `CATPPUCCIN_EZA_START` / `CATPPUCCIN_EZA_END`
- `CATPPUCCIN_FZF_START` / `CATPPUCCIN_FZF_END`
- `CATPPUCCIN_GHOSTTY_THEME_START` / `CATPPUCCIN_GHOSTTY_THEME_END`

The marker names are historical; they are the managed insertion points regardless of selected family.

## Oh My Posh format

Oh My Posh configs stay JSON in this repo.

Use these paths:

```text
home/.config/oh-my-posh/config.json
assets/themes/oh-my-posh/<family>/<flavor>.json
```

Do not convert OMP assets to TOML unless the repo decision changes.

## bat cache behavior

After deploying a bat theme, `./dots apply` checks whether `bat` exists before running:

```bash
bat cache --build
```

If `bat` is missing, the deploy logs an informational skip instead of failing. The E2E suite asserts the apply output stays quiet and does not expose bat cache internals like `Writing theme set`.

## Ghostty shader policy

Ghostty keeps only the cursor smear shader:

```text
home/.config/ghostty/shaders/cursor_smear.glsl
```

Do not add extra Ghostty shaders unless the policy changes.

## Add or update a theme flavor

1. Add matching source assets under each relevant `assets/themes/<tool>/<family>/` directory.
2. Keep Oh My Posh assets as JSON.
3. Use file names consistent with the existing family/tool conventions.
4. Confirm configs using placeholders still render correctly.
5. Validate:

```sh
make lint
./dots doctor
make e2e
```

Run `./dots doctor` after deploying a changed theme locally so the generated marker blocks, required config files, Oh My Posh JSON, Ghostty theme block, and related smoke checks are verified against `$HOME`.

For behavior changes to theme selection or deploy rules, create/update an OpenSpec change before editing implementation.
