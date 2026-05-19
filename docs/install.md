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

With `--yes`, `./dots select --yes` skips the pickers, uses values from `manifest.json` (or hardcoded defaults if no manifest), and runs the full deploy pipeline immediately.

## Selection lifecycle

There is no selection file. `./dots select` runs the wizard and the deploy pipeline in one step. The single durable record of a deployed selection is `manifest.json`.

**Sources of truth:**

- `manifest.json` — written by `./dots select`, `./dots apply`, `./dots update`, and `./dots sync` after every successful deploy. Holds theme/flavor/accent/tools plus `source_hash` and `applied_at`.
- Hardcoded defaults in `lib/select.sh` (`_SELECT_DEFAULT_THEME=kanagawa`, etc.) — used only when no manifest exists yet (fresh clone).

**Schema of the deployed state (as serialized in `manifest.json`):**

```json
{
  "version": "2.0.0",
  "theme": "kanagawa",
  "flavor": "dragon",
  "accent": "mauve",
  "tools": ["zsh", "tmux", "nvim", "ghostty", "oh-my-posh", "atuin", "zoxide"],
  "source_hash": "<64-hex>",
  "applied_at": "<ISO 8601 UTC>"
}
```

**Fields (selection portion):**

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

`./dots select` and `./dots apply` reject unknown themes, flavors, accents, or tools (no matching asset) with a non-zero exit.

## Interactive subcommands

| Command | Description |
| --- | --- |
| `./dots select` | Wizard + full deploy in one step. Interactive entry for any change. |
| `./dots apply` | Non-interactive replay of the deploy pipeline using state from `manifest.json` (or defaults). |
| `./dots update` | Re-deploy from `manifest.json` without source-hash check or backup. |
| `./dots sync` | Re-deploy from `manifest.json` only when source hash differs; `--force` skips the check. |
| `./dots doctor` | Non-mutating health checks on deployed dotfiles. |
| `./dots restore --latest` | Restore the newest backup from `.backups/`. |
| `./dots uninstall` | Remove managed payload and `manifest.json`. |

## Doctor

```sh
./dots doctor
./dots doctor --help
```

`doctor` runs local, non-mutating health checks against deployed dotfiles. Checks cover required paths, Oh My Posh JSON syntax, config-content markers (tmux prefix, Ghostty theme block, BAT_THEME), and Homebrew presence.

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
