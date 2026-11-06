# Install Guide

This repo deploys via [dotbot] + [dotbot-brew] + [dotbot-mise]. The `./dots` command wraps the lifecycle.

[dotbot]: https://github.com/anishathalye/dotbot
[dotbot-brew]: https://github.com/d12frosted/dotbot-brew
[dotbot-mise]: https://github.com/s0cks/dotbot-mise

## Requirements

- macOS: Xcode Command Line Tools (provides `git` + `python3`). `./dots` triggers `xcode-select --install` automatically if either is missing.
- Linux: `python3`, `git`, and standard build deps. `./dots` installs them via `apt-get`, `dnf`, or `pacman` automatically on first run.

Homebrew is **not** a prerequisite — `./install` installs it via a dotbot `shell` directive on first run.

## First install

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./dots
```

`./dots` is the only command you need. On a fresh machine it auto-bootstraps:

1. Detects missing `python3` / `git` / Linux build deps and installs them via `apt-get`, `dnf`, or `pacman` (Linux) or triggers `xcode-select --install` (macOS).
2. Runs `git submodule update --init --recursive` to materialize `dotbot/`, `plugins/dotbot-brew/`, `plugins/dotbot-mise/`.
3. Sees that `manifest.json` is absent → the dispatcher auto-runs `update` (no flags) with the default kanagawa/dragon theme. On a TTY `update` still shows its `Change theme?` prompt (default No); without a TTY it applies the defaults without asking.
4. Invokes `./install` (the dotbot wrapper), which runs dotbot against `config/install.conf.yaml`:
   - `shell:` installs Homebrew if missing.
   - `brewfile:` runs `brew bundle --file=config/Brewfile`.
   - `create:` ensures every `~/.config/<app>/` parent exists.
   - `link:` creates every symlink from `$HOME` into the repo.
   - `mise:` runs `mise install`.
   - `shell:` rebuilds the bat cache.
5. The theme switcher applies kanagawa/dragon.
6. Existing regular files in `$HOME` are moved to `<path>.dotbot-backup.<timestamp>` before being replaced by symlinks (dotbot `backup: true` default).

`./dots` is the only entry point. There is no `bootstrap.sh`. The auto-bootstrap lives in `src/lib/bootstrap.sh` and is invoked from `src/lib/dotbot.sh:dotbot_check_submodules`, so any subcommand that touches dotbot (update, sync, theme, clean, upgrade) triggers it on a fresh machine.

## Non-interactive install

```sh
./dots update --yes --theme=kanagawa --flavor=dragon
```

Supported flags on `./dots update`:

```sh
--yes                      # skip confirmation prompts
--theme=kanagawa|catppuccin
--flavor=dragon|lotus|wave|frappe|latte|macchiato|mocha
--pull                     # git pull --ff-only before invoking dotbot
```

The `--tools` flag is **removed**. Managed packages are declared in `config/Brewfile` (brew formulae/casks/taps) and `content/home/.config/mise/config.toml` (runtime versions). Edit those files and re-run `./dots update`.

## Everyday commands

Run `./dots` for the visual action menu: a one-line status (active theme, prompt engine and local git state of the repo) above the actions, grouped and each with a short description. Move with ↑↓ or j/k, run with enter, quit with q or esc. On first run (when `manifest.json` is absent), `./dots` auto-starts `update`.

| Command | Use when you want to... |
| --- | --- |
| `./dots` | Open the visual action menu. |
| `./dots update [--pull] [--theme=X --flavor=Y] [--yes]` | Run `./install` (full base config) then apply the active theme. `--pull` runs `git pull --ff-only` first. On a TTY with no flags, `Change theme?` defaults to No; press Enter to reapply the manifest theme, or Y to choose a new theme/flavor. |
| `./dots theme <theme> <flavor>` | Switch theme (or `./dots theme` for interactive picker, `--current` to show active). |
| `./dots doctor` | Non-mutating health check. |
| `./dots clean [--age=N] [--dry-run]` | Remove dead symlinks; prune `*.dotbot-backup.*` older than N days (default 30). |
| `./dots upgrade [--commit] [--dry-run]` | Bump pinned submodule commits; `brew bundle cleanup`; `mise prune`. |
| `./dots uninstall [--yes] [--dry-run]` | Remove declared Dotbot symlinks + `manifest.json`. Preserves `.dotbot-backup.*` siblings. |

In scripts or CI, use an explicit subcommand. The no-args menu requires a TTY.

Interactive `./dots update` replaces the old re-sync flow: the `Change theme?` prompt defaults to No, so pressing Enter re-runs the base config and reapplies the manifest theme without opening pickers.

## Local Docker runtime

OrbStack owns the Docker engine and command-line toolchain. Start it when needed, then verify the workflow:

```sh
orb start
docker context show          # orbstack
docker version
docker compose version
docker buildx version
```

OrbStack provides and updates Docker, Compose, and Buildx. Do not install competing Homebrew Docker CLI packages or set a global `DOCKER_HOST`; OrbStack activates its `orbstack` Docker context automatically.

## Themes

Supported themes:

| Theme | Flavors |
| --- | --- |
| `kanagawa` | `dragon`, `lotus`, `wave` |
| `catppuccin` | `frappe`, `latte`, `macchiato`, `mocha` |

Change theme:

```sh
./dots theme catppuccin mocha   # non-interactive
./dots theme                    # interactive picker
./dots theme --current          # print active theme
```

The theme switcher re-links the per-app theme files (`~/.config/bat/themes/dots.tmTheme`, etc.), rewrites the fenced Starship `palette` and Herdr `theme.name` lines, persists `DOTS_THEME` in `~/.config/zsh/local.zsh` (read by tmux's `@themux_theme` and the p10k palette), rebuilds the bat cache, reloads running tmux/Herdr servers, and writes `manifest.json`.

If a running tmux session does not pick up the new theme after `./dots theme`, run `tmux kill-server` and restart tmux.

## Recovery

There is no `./dots backup` or `./dots restore`. Recovery paths:

| Situation | Action |
| --- | --- |
| You broke a file in `$HOME` (it's a symlink to repo) | `git checkout -- content/home/<path>` in the repo. |
| You broke a file in the repo | `git checkout <good-sha> -- content/home/<path>`. |
| You need the original file from before bootstrap | Look in `$HOME` for `<path>.dotbot-backup.<timestamp>` siblings. |
| The symlink farm is corrupt | `./dots update --yes` (idempotent re-link). |
| You want to roll back the whole repo | `git checkout <good-sha>` then `./dots update --yes`. |

## Health check

After install or updates:

```sh
./dots doctor
```

Doctor checks: required commands (`python3`, `brew`, `zsh`, `tmux`, `herdr`, `orb`, `docker`, `docker buildx`, `docker compose`, `nvim`, `git`, `jq`), submodule presence (`dotbot`, `dotbot-brew`, `dotbot-mise`), required symlinks (home `.zshenv`, ZDOTDIR zsh files/fragments, nvim, tmux, ghostty, herdr, mise, bat, fzf, eza), theme symlinks, theme agreement, content markers (tmux prefix, ghostty theme, bat/fzf/eza config, Starship init), tmux fence, Starship/Herdr fences, slim manifest schema, stale `*.dotbot-backup.*` files (WARN).

If doctor reports a fail, the most common fix:

```sh
./dots update --yes
./dots doctor
```

## Post-install

```sh
exec zsh
./dots doctor
```

Then:

1. Open tmux and install plugins with `Ctrl-a I`.
2. Open Neovim; plugins install on first launch.

## Maintenance

Periodically:

```sh
./dots clean                 # prune stale dotbot-backup files
./dots upgrade --dry-run     # see what bumps + cleanups would happen
./dots upgrade --commit      # apply + commit
```
