# Install Guide

## Prerequisites

**macOS**: `curl` only. Git is picked up via Xcode Command Line Tools or installed automatically by Homebrew.

**Linux**: `curl`, `git`, and `sudo`. The bootstrap installs build-essential (or equivalent) and Homebrew via `sudo` before running the Brewfile.

No Go or Docker required for a standard install.

## Bootstrap

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./bootstrap.sh
```

`bootstrap.sh` orchestrates:

1. OS/arch detection.
2. Linux system deps (`apt-get` / `dnf` / `pacman` — build-essential, curl, git, unzip, fontconfig).
3. Homebrew install (if missing).
4. `brew bundle --file=Brewfile`.
5. Interactive theme/tool wizard (`./dots select`).
6. Deploy (`./dots apply`).

## Non-interactive install

```sh
./bootstrap.sh --yes --theme=kanagawa --flavor=dragon
```

Supported flags: `--yes`, `--theme`, `--flavor`, `--accent`, `--tools`.

With `--yes`, the wizard is skipped and the existing `.dots-selection.json` is used (or defaults are written if absent).

## Selection file format

`./dots select` writes a `.dots-selection.json` at the repository root:

```json
{
  "theme": "kanagawa",
  "flavor": "dragon",
  "accent": "mauve",
  "tools": ["zsh", "tmux", "nvim", "ghostty", "oh-my-posh", "atuin", "zoxide"]
}
```

**Fields:**

| Field | Type | Description |
| --- | --- | --- |
| `theme` | string | Theme family. Valid: `kanagawa`, `catppuccin`. |
| `flavor` | string | Variant within the family (see below). |
| `accent` | string | Accent color (catppuccin only). Valid: `mauve`, `blue`, `green`, `peach`, `pink`, `red`, `yellow`. Ignored for kanagawa. |
| `tools` | array of strings | Tools to deploy. Valid members: `zsh`, `tmux`, `nvim`, `ghostty`, `oh-my-posh`, `atuin`, `zoxide`. |

**Valid themes and flavors:**

| Theme | Flavors |
| --- | --- |
| `kanagawa` | `wave`, `dragon`, `lotus` |
| `catppuccin` | `latte`, `frappe`, `macchiato`, `mocha` |

The selection wizard rejects unknown themes or flavors (no matching asset under `assets/themes/oh-my-posh/<theme>/<flavor>.json`) with a non-zero exit.

## Local override pattern

For machine-specific preferences that should not be committed, create `.dots-selection.local.json` next to `.dots-selection.json`:

```json
{
  "theme": "catppuccin",
  "flavor": "mocha",
  "accent": "mauve",
  "tools": ["zsh", "tmux", "nvim", "ghostty", "oh-my-posh", "atuin", "zoxide"]
}
```

Lookup order: `.dots-selection.local.json` (if present) takes precedence over `.dots-selection.json`.

`.dots-selection.local.json` is listed in `.gitignore` and is never committed. The committed `.dots-selection.json` holds shared defaults.

> **Note:** `.local.json` precedence is specified in the selection-file spec and is the intended behavior. Verify that `commands/apply.sh` in your checkout implements this check if you rely on it; the pattern will be wired automatically once the precedence logic is added to the apply/update/reload commands.

## Interactive subcommands

| Command | Description |
| --- | --- |
| `./dots select` | Re-run the theme/tool wizard; writes `.dots-selection.json`. |
| `./dots apply` | Validate selection → backup → deploy → write manifest. |
| `./dots update` | Re-deploy configs and theme assets without checking source hash. |
| `./dots reload` | Re-deploy only when `home/` or `assets/themes/` source hash changed; `--force` skips the check. |
| `./dots doctor` | Non-mutating health checks on deployed dotfiles. |
| `./dots restore --latest` | Restore the newest backup from `$HOME/.dotfiles_backups/`. |
| `./dots uninstall` | Remove managed payload and `manifest.json`. |

## Doctor

```sh
./dots doctor
./dots doctor --help
```

`doctor` runs local, non-mutating health checks against deployed dotfiles. Checks cover required paths, Oh My Posh JSON syntax, config-content markers (tmux prefix, Ghostty theme block, BAT_THEME, ZDOTDIR), and Homebrew presence.

Doctor does not install dependencies, repair files, or perform network calls. Run it after install/update/reload to catch config drift.

## Reload vs update

Use `reload` when you only want to apply repo source drift (hash changed). Use `update` for unconditional target repair.

## Backups and manifest

Before deploying, `apply` creates a timestamped backup:

```text
$HOME/.dotfiles_backups/YYYY-MM-DD_HHMMSS/
```

A `manifest.json` at the repo root records:

- `deployed_at`
- `version`
- `theme`
- `flavor`
- `accent`
- `source_hash`

## Post-install checks

```sh
exec zsh
./dots doctor
which oh-my-posh
bat --config-dir
nvim
```

Tmux uses `Ctrl-a` as prefix. Install/update tmux plugins with `Ctrl-a I` after opening a session.
