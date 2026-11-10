# Install Guide

This repo deploys via [dotbot] + [dotbot-brew] + [dotbot-mise]. The `./dots` command wraps the lifecycle.

[dotbot]: https://github.com/anishathalye/dotbot
[dotbot-brew]: https://github.com/d12frosted/dotbot-brew
[dotbot-mise]: https://github.com/s0cks/dotbot-mise

## Requirements

- macOS: Xcode Command Line Tools (provides `git` + `python3`). `./dots` triggers `xcode-select --install` automatically if either is missing.
- Linux: `python3`, `git`, and standard build deps. `./dots` installs them via `apt-get`, `dnf`, or `pacman` automatically on first run.

Linux is supported on a best-effort basis: the shell config, symlinks, theme switching, `mise` and the Brewfile's formulae (Homebrew on Linux) work, while everything macOS-only is skipped (see [Linux status](#linux-status)). It is exercised by the Linux CI container (shellcheck and the bats suite), not by a full install on a real Debian/Ubuntu desktop, so expect rough edges.

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
   - `shell:` installs Homebrew if missing, from `Homebrew/install` at a pinned commit (bump procedure in the comment above it in `config/install.conf.yaml`). It stays interactive (no `NONINTERACTIVE=1`).
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

Any other argument (a bare word, an unknown flag, a single-dash flag) is an error: it is named on stderr, the exit status is 2 and nothing runs.

The `--tools` flag is **removed**. Managed packages are declared in `config/Brewfile` (brew formulae/casks/taps) and `content/home/.config/mise/config.toml` (runtime versions). Edit those files and re-run `./dots update`.

A tap outside Homebrew's official ones needs trust before Homebrew loads its formulae or casks. The Brewfile trusts each such tap only for the items it installs (`tap "x/y", trusted: { formulae: [...] }` or `casks: [...]`), with a `# trusted:` comment above saying why. When you add an item from one of those taps, add its name to that list; `tests/dependency_pins.bats` checks that every listed name is installed and every trusted tap has its comment.

## Linux status

What works on Debian/Ubuntu (and is covered by `tests/linux_portability.bats`):

- **`bat` and `fd`**: Debian installs them as `batcat` and `fdfind`. The zsh files pick the Debian name when the plain one is not on `PATH` (`DOTS_BAT` / `DOTS_FD`, set in `~/.config/zsh/.zshenv`) and use it for `PAGER`, `MANPAGER`, the `cat`/`fp`/suffix aliases, the `find` abbreviation and the fzf commands and previews; `bat` and `fd` are also aliased to the Debian names for interactive use. Homebrew's own `bat`/`fd` keep their plain names.
- **macOS-only shell function** (`cdf`) is not defined on Linux, like the macOS-only clipboard alias `C` (Linux gets `wl-copy`/`xclip` when present).
- **`dots` in zsh** runs the repo it is linked from, wherever you cloned it (`~/.dotfiles` is no longer required). Export `DOTS_REPO=/path/to/clone` to pin a checkout; `~/.dotfiles` is the last resort when `functions.zsh` was copied instead of linked. The `dotfiles` alias opens the same path.
- **`./dots doctor`** reports the macOS-only checks as `[SKIP] ... macOS only` instead of failing: OrbStack, the Docker CLI and its buildx/compose plugins (Docker comes from OrbStack here), and the ghostty config, theme link and theme marker (ghostty is a macOS cask in the Brewfile). A skipped check counts as passed in the summary.

Known gaps on Linux:

- The post-link `bat cache --build` step (`config/install.conf.yaml`) and the theme switcher's bat-cache rebuild look for a command named `bat`, so they are skipped when only `batcat` exists (the theme switcher warns). To get them back, put a `bat` on `PATH`: `mkdir -p ~/.local/bin && ln -s "$(command -v batcat)" ~/.local/bin/bat` (and `fd` likewise for `fdfind`), then re-run `./dots theme <theme> <flavor>`.
- Terminal components are opt-in (`./dots components`): on Linux the Herdr app comes from Herdr's official installer when `herdr-app` is selected, the Herdr core from the core installer when `herdr-core` is selected (not when the app is), and Ghostty is not installed (its cask is macOS-only), though its config is still linked when `ghostty` is selected. Unchecking a recorded component uninstalls it after a confirmation (see `./dots components` below); on Linux that removes the official Herdr app install (`${XDG_DATA_HOME:-~/.local/share}/herdr-app`, `~/.local/bin/herdr-app`, its `.desktop`/icon files).
- The macOS-only Brewfile entries (casks, AeroSpace, duti, OrbStack, ghostty), the Finder Quick Action and the VSCodium default-app step are not installed or linked on Linux.
- The Homebrew installer needs `curl` and the build dependencies `./dots` installs through `apt-get`, `dnf` or `pacman`.

## Everyday commands

Run `./dots` for the visual action menu: a one-line status (active theme, prompt engine and local git state of the repo) above the actions, grouped and each with a short description. Move with ↑↓ or j/k, run with enter, quit with q or esc. On first run (when `manifest.json` is absent), `./dots` auto-starts `update`.

| Command | Use when you want to... |
| --- | --- |
| `./dots` | Open the visual action menu. |
| `./dots update [--pull] [--theme=X --flavor=Y] [--yes]` | Run `./install` (full base config) then apply the active theme. `--pull` runs `git pull --ff-only` first. On a TTY with no flags, `Change theme?` defaults to No; press Enter to reapply the manifest theme, or Y to choose a new theme/flavor. On a TTY it also asks the component checklist once while none is recorded (`./dots components`); `--yes` never asks. Unknown arguments are rejected (stderr, exit 2). |
| `./dots theme <theme> <flavor>` | Switch theme (or `./dots theme` for interactive picker, `--current` to show active). |
| `./dots font <font>` | Switch the terminal font: `jetbrains-mono` (default) or `iosevka` (or `./dots font` for the picker, `--current` to show active). On macOS the Nerd Font cask is installed when missing. |
| `./dots components [--yes] [<id>... \| none]` | Choose with checkboxes which terminal components you want: `tmux`, `herdr-tui`, `herdr-core`, `herdr-app` (checking it also checks `herdr-core`) and `ghostty`. None are checked by default. Recorded machine-locally as `DOTS_COMPONENTS` in `~/.config/zsh/local.zsh`; `./dots components` opens the checklist, `--current` shows the selection, and `./dots update` asks it once on a TTY while nothing is recorded (`--yes` never asks). `./dots update` then installs (Brewfile entries, Herdr installers), links, themes (tmux reload, Herdr fence, Ghostty theme link) and checks (`./dots doctor`) only the selected components; nothing recorded or `none` means none of them. Unchecking a component that was recorded as selected uninstalls it (`brew uninstall` of `tmux`+`gitmux`, `herdr`, the `herdr-app`/`ghostty` casks; on Linux the official Herdr app install dir, launcher and desktop files; the `herdr-core` files `~/.local/bin/herdr-core` and `hc` when they are regular files or symlinks) and removes its symlinks into this repo (`~/.config/tmux/*`; the Herdr config only when no Herdr component remains; Ghostty `config`, `shaders`, `themes/dots`, never `font.conf`), after a confirmation that lists exactly what goes (default No). `--yes` skips it; without a TTY and without `--yes` a removing change exits 2 and changes nothing; declining changes nothing. Components never recorded are never uninstalled (the first selection removes nothing). A missing package is skipped; a failing uninstall warns, the exit code is non-zero and the selection is still recorded. |
| `./dots doctor` | Non-mutating health check. On Linux the macOS-only checks are skipped, not failed. |
| `./dots clean [--age=N] [--dry-run]` | Remove dead symlinks that point into this repo; prune dotbot backups of declared links older than N days (default 30). Never touches links or backups the repo did not create. |
| `./dots upgrade [--commit] [--dry-run]` | Bump pinned submodule commits; `brew bundle cleanup`; `mise prune`. `--commit` commits only the gitlinks it advanced; other staged files stay staged. |
| `./dots uninstall [--yes] [--dry-run]` | Remove declared Dotbot symlinks + `manifest.json`. Preserves `.dotbot-backup.*` siblings. |
| `./dots help` | Usage on stdout (exit 0). An unknown command prints the error and usage on stderr (exit 2). |

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

Doctor checks (the tmux, Herdr and Ghostty ones are skipped as `[SKIP] ... not selected` for components you did not select): required commands (`python3`, `brew`, `zsh`, `tmux`, `herdr`, `orb`, `docker`, `docker buildx`, `docker compose`, `nvim`, `git`, `jq`), submodule presence (`dotbot`, `dotbot-brew`, `dotbot-mise`), required symlinks (home `.zshenv`, ZDOTDIR zsh files/fragments, nvim, tmux, ghostty, herdr, mise, bat, fzf, eza), theme symlinks, theme agreement, the nvim theme link, content markers (tmux prefix, ghostty theme, bat/fzf/eza config, Starship init), tmux fence, Starship/Herdr fences, slim manifest schema, stale `*.dotbot-backup.*` files (WARN).

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

1. Open tmux: the first start clones TPM and the plugins at their pinned commits (see [plugins.md](plugins.md#pinned-versions)).
2. Open Neovim; plugins install on first launch.

## Maintenance

Periodically:

```sh
./dots clean                 # prune stale dotbot-backup files
./dots upgrade --dry-run     # see what bumps + cleanups would happen
./dots upgrade --commit      # apply + commit only the advanced gitlinks
```
