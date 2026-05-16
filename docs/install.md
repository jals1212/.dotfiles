# Install Guide

## Prerequisites

- macOS or Linux shell environment.
- Go for local builds.
- Docker/OrbStack only if running the E2E suite.
- On macOS, Homebrew is expected for the package set in `Brewfile`.

The installer is intentionally current-state only: old layouts and deprecated workflows are not preserved.

## Build

```bash
make build
```

This compiles `installer/cmd/dots` into the root `./dots` binary.

## Interactive install

```bash
./dots
# or
./dots install
```

The TUI walks through:

1. theme family selection,
2. flavor selection,
3. theme preview,
4. tool selection,
5. backup confirmation,
6. installation progress,
7. summary and post-install instructions.

Default selected tools are Ghostty, tmux, Neovim, Oh My Posh, Atuin, zoxide, and Zsh.

## Non-interactive install

```bash
./dots install --yes
```

Non-interactive mode installs the default selected stack and uses environment variables for theme selection:

```bash
DOTS_THEME=kanagawa DOTS_FLAVOR=dragon ./dots install --yes
DOTS_THEME=catppuccin DOTS_FLAVOR=mocha ./dots install --yes
```

If the variables are empty, the installer defaults to `kanagawa/dragon`.

## Update configs

```bash
./dots update
```

`update` re-deploys managed configs and theme blocks from the current repository without running the full selection flow. It uses `DOTS_THEME` and `DOTS_FLAVOR`, defaulting to `kanagawa/dragon`.

## Reload when source changed

```bash
./dots reload
./dots reload --force
```

`reload` compares the current source hash for `home/` and `assets/themes/` with the `source_hash` stored in `manifest.json`. If the hash matches, it reports that configs are already current and skips deploy. If the hash is missing or changed, it re-deploys configs and saves a new manifest. Use `--force` to re-deploy regardless of the stored hash.

Use `update` when you want unconditional target repair; use `reload` when you only want to apply repo source drift.

## Doctor

```bash
./dots doctor
./dots doctor --help
```

`doctor` runs local, non-mutating health checks against deployed dotfiles. It checks required deployed paths, Oh My Posh JSON syntax, generated marker uniqueness, and essential config-content smoke checks for the managed shell, Neovim, tmux, Ghostty, bat, and AeroSpace files.

Doctor intentionally does not install dependencies, repair files, call package managers, or perform network checks. Use it after install/update/reload to catch local config drift before opening the tools.

## Uninstall

```bash
./dots uninstall
```

`uninstall` removes managed payload entries that correspond to files/directories under `home/` and removes the repo-local `manifest.json`. Use `dots restore` if you want to restore a backup afterward.

## Restore

```bash
./dots restore --latest
./dots restore "$HOME/.dotfiles_backups/YYYY-MM-DD_HHMMSS"
```

`restore --latest` selects the lexicographically newest backup directory under `$HOME/.dotfiles_backups`. A specific backup path restores that directory instead. Restore overwrites matching files in `$HOME`.

## Backups and manifest

When backup is enabled from the TUI, existing managed targets are copied to:

```text
$HOME/.dotfiles_backups/YYYY-MM-DD_HHMMSS/
```

The installer writes a repo-local `manifest.json` with deployment metadata:

- `deployed_at`
- `version`
- `theme`
- `flavor`
- `source_hash`

## Validation

Fast local validation:

```bash
make test
openspec validate --all --strict
```

After deploying configs locally, run:

```bash
./dots doctor
```

Full E2E validation:

```bash
make docker-test
```

`make docker-test` performs these steps:

1. builds `./dots`,
2. builds `installer/Dockerfile` as `dots-test`,
3. runs `installer/e2e/e2e_test.sh` inside the container.

The E2E suite checks CLI help, non-interactive install, deployed config files, quiet bat cache output, JSON validity for Oh My Posh, key shortcut policy, Ghostty shader policy, update idempotency, and reload no-op behavior.
It also verifies that `dots restore --latest` restores backed-up files.

## Post-install checks

```bash
exec zsh
./dots doctor
which oh-my-posh
bat --config-dir
nvim
```

`dots doctor` is the repo-owned smoke check for deployed dotfiles. It validates local files and config content only; it does not replace opening tmux/Neovim/Ghostty or installing tmux/LazyVim plugins on first launch.

Tmux uses `Ctrl-a` as prefix. Install/update tmux plugins with `Ctrl-a I` after opening a session.
