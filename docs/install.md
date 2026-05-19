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

With `--yes`, the wizard is skipped: `./dots select --yes` materializes a transitory `.dots-selection.json` from `manifest.json` (if present) or hardcoded defaults, and `./dots apply` consumes it.

## Selection lifecycle

`.dots-selection.json` is **transitory** — it lives only between `./dots select` and `./dots apply`. Once apply writes the manifest, the selection file is removed; the manifest becomes the source of truth.

The file is listed in `.gitignore` and is never committed.

**Lifecycle:**

1. `./dots select` writes `.dots-selection.json` pre-populated from `manifest.json` (post-apply state) if present, else from hardcoded defaults in `lib/select.sh`.
2. `./dots apply` reads `.dots-selection.json`, deploys, writes `manifest.json`, then removes `.dots-selection.json`.
3. `./dots update` and `./dots reload` read theme/flavor/accent/tools from `manifest.json`; they do not require the selection file.

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

## Interactive subcommands

| Command | Description |
| --- | --- |
| `./dots select` | Re-run the theme/tool wizard; writes the transitory `.dots-selection.json` (pre-populated from manifest or defaults). |
| `./dots apply` | Validate selection → backup → deploy → write manifest → remove the transitory selection. |
| `./dots update` | Re-deploy using state from `manifest.json`; no source-hash check. |
| `./dots reload` | Re-deploy using state from `manifest.json` only when source hash differs; `--force` skips the check. |
| `./dots doctor` | Non-mutating health checks on deployed dotfiles. |
| `./dots restore --latest` | Restore the newest backup from `$HOME/.dotfiles_backups/`. |
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
