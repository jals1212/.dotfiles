# Themes

Use `./dots update` to change theme/flavor. Use `./dots sync` to re-apply the current theme.

## Change theme interactively

```sh
./dots update
```

The picker lets you choose:

1. Theme family
2. Flavor
3. Accent, for Catppuccin
4. Tools to apply

## Change theme non-interactively

```sh
./dots update --yes --theme=kanagawa --flavor=dragon
./dots update --yes --theme=catppuccin --flavor=mocha --accent=mauve
```

## Supported themes

| Theme | Flavors |
| --- | --- |
| `kanagawa` | `dragon`, `lotus`, `wave` |
| `catppuccin` | `latte`, `frappe`, `macchiato`, `mocha` |

Catppuccin accents:

```text
mauve, blue, green, peach, pink, red, yellow
```

## What gets themed

- Oh My Posh prompt
- Ghostty
- tmux/tmux-ukiyo
- Neovim
- Atuin
- bat
- eza
- fzf
- bottom
- lazygit

## Re-apply current theme

```sh
./dots sync
```

Force re-apply:

```sh
./dots sync --force
```

## Check theme health

```sh
./dots doctor
```
