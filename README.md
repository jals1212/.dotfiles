# ⁘ JALS DOTS

Personal dotfiles deployed with [dotbot] + [dotbot-brew] + [dotbot-mise]. The `./dots` command wraps the lifecycle: install, update, switch theme, doctor, clean, upgrade, uninstall.

Default theme: `kanagawa/dragon`.

[dotbot]: https://github.com/anishathalye/dotbot
[dotbot-brew]: https://github.com/d12frosted/dotbot-brew
[dotbot-mise]: https://github.com/s0cks/dotbot-mise

## Quick Start

```sh
git clone <repo> ~/.dotfiles
cd ~/.dotfiles
./dots
```

`./dots` is the only entry point you need. On a fresh machine it auto-detects missing prerequisites and bootstraps them (Linux build deps via apt/dnf/pacman, Xcode CLT on macOS, submodule init) before invoking dotbot.

Non-interactive:

```sh
./dots update --yes --theme=kanagawa --flavor=dragon
```

`./dots` is the only entry point. `bootstrap.sh` is removed — no compat alias.

## Lifecycle

| Command | What it does |
|---|---|
| `./dots update [--pull] [--theme=X --flavor=Y] [--yes]` | Runs `./install` (dotbot base config: brew install if missing, `brew bundle`, every symlink, `mise install`) then applies the active theme. With no flags on a TTY, shows `Change theme?` defaulting to No; press Enter to re-apply the manifest theme, or Y to open the pickers. With `--pull`, runs `git pull --ff-only` first. On a TTY it also asks the component checklist once while no `DOTS_COMPONENTS` is recorded (see `./dots components`); `--yes` never asks. Any other argument is rejected (error on stderr, exit 2) before anything runs. |
| `./dots theme <theme> <flavor>` | Switches the active theme. Re-links the 7 per-app theme files; rewrites the Starship (`palette`) and Herdr (`theme.name`) fenced lines; persists `DOTS_THEME` in `~/.config/zsh/local.zsh` (read by tmux's `@themux_theme` and the p10k palette); rebuilds the bat cache; reloads running tmux/Herdr servers; writes the slim manifest. |
| `./dots font <font>` | Switches the terminal font: `jetbrains-mono` (default) or `iosevka`. Machine-local: writes `font-family` to `~/.config/ghostty/font.conf` (loaded by the Ghostty config with `config-file = ?font.conf`) and `DOTS_FONT` to `~/.config/zsh/local.zsh`; on macOS installs the font's Nerd Font cask when missing, and `config/Brewfile` declares only the chosen font, so `./dots upgrade --cleanup` keeps it. `./dots font` alone opens a picker; `--current` prints the active font. `./dots update` re-applies it and, on a TTY, asks once while no font is recorded. |
| `./dots components [--yes] [<id>... \| none]` | Chooses which terminal components you want, as checkboxes: `tmux` (tmux + gitmux), `herdr-tui` (Herdr TUI), `herdr-core` (Herdr core), `herdr-app` (Herdr desktop app) and `ghostty`. Nothing is checked by default; checking `herdr-app` also checks `herdr-core` (the app brings it). Machine-local: recorded as `DOTS_COMPONENTS` in `~/.config/zsh/local.zsh` (space-separated ids in that fixed order, `none` for an empty selection, no line when never recorded); the repo never changes. `./dots components` alone opens the checklist (space toggles, enter confirms, q cancels and changes nothing); `./dots components <id>...` sets it non-interactively (an unknown id exits 1 and changes nothing); `--current` prints it. `./dots update` asks the same checklist once on a TTY while nothing is recorded (`--yes` never asks). Unchecking a component that was recorded as selected uninstalls it and removes its repo symlinks, after a confirmation that lists exactly what goes (default No; `--yes` skips it, and without a TTY and without `--yes` a change that removes something exits 2 and changes nothing); see *Unchecking* below. `./dots update` then installs, links, themes and checks only the selected components (see below). |
| `./dots doctor` | Non-mutating: symlink integrity, theme symlink agreement, content markers, Starship/Herdr theme fences, slim manifest schema, submodule presence, stale dotbot-backup warning, machine-local `local.zsh` state whitelist (`DOTS_PROMPT`, `DOTS_FONT`, `DOTS_COMPONENTS`). The tmux, Herdr and Ghostty checks of components you did not select are skipped (`[SKIP] ... not selected`), not failed. On Linux the macOS-only checks (OrbStack, Docker, ghostty) are skipped, not failed ([Linux status](docs/install.md#linux-status)). |
| `./dots clean [--age=N] [--dry-run]` | Removes broken symlinks that point into this repo and prunes dotbot backups (`<link>.dotbot-backup.<timestamp>`) of links this repo declares, older than `N` days (default 30). Links and backups it did not create are never touched. |
| `./dots upgrade [--commit] [--dry-run]` | Bumps pinned submodule commits, runs `brew bundle cleanup`, `mise prune`. With `--commit`, commits only the gitlinks it advanced; other staged changes stay staged. |
| `./dots uninstall [--yes] [--dry-run]` | Removes declared Dotbot symlinks and `manifest.json`. Preserves `*.dotbot-backup.*` siblings. |
| `./dots help` (`-h`, `--help`) | Prints the usage on stdout (exit 0); an unknown command prints the error and usage on stderr (exit 2). |
| `./dots` (no args) | TTY: action menu. Non-TTY + manifest absent: auto-runs `update`. Non-TTY + manifest present: errors. |

Every subcommand opens with a one-line header, `⁘ jals1212 DOTS · <command> · <theme> · <prompt> · <git>`, instead of a logo; the menu already shows the same line, so subcommands run from it skip it.

## Themes

Supported themes:

- `kanagawa`: `dragon`, `lotus`, `wave`
- `catppuccin`: `frappe`, `latte`, `macchiato`, `mocha`

Switch theme:

```sh
./dots theme kanagawa dragon
./dots theme              # interactive picker
./dots theme --current    # show active theme
```

### Terminal components

`./dots update` only installs, links and themes the components you selected with `./dots components`; nothing recorded, or `none`, means none of them:

| Component | Installed by | Linked | Themed |
|-----------|--------------|--------|--------|
| `tmux` | `brew "tmux"` + `brew "gitmux"` | `~/.config/tmux/*` | running server reloaded |
| `herdr-tui` | `brew "herdr"` | `~/.config/herdr/config.toml` (also for `herdr-core`/`herdr-app`) | fenced `theme.name`, running server reloaded |
| `herdr-core` | official installer `https://releases.herdr.dev/core/install.sh` (macOS and Linux; skipped when `herdr-core` is already on `PATH` or in `~/.local/bin`, and on Linux when `herdr-app` is selected, since the official app installer brings the core; on macOS it runs with `herdr-app` too, since the cask brings no core) | Herdr config | same |
| `herdr-app` | macOS: `cask "herdr-app"` (an official install in `~/Applications/Herdr.app` is moved out first, see below); Linux: official installer `https://releases.herdr.dev/app/install.sh` | Herdr config | same |
| `ghostty` | `cask "ghostty"` (macOS only) | `~/.config/ghostty/config` and `shaders` (any OS) | `~/.config/ghostty/themes/dots` link |

The Herdr installers are the official ones, unpinned, and only warn when they fail. Homebrew has no Herdr core package, so the core updates through its own installer, not `brew upgrade`.

On macOS, `./dots update` with `herdr-app` selected moves an official Herdr app install out of the way before Homebrew runs, so the cask is the only copy: it lists `~/Applications/Herdr.app` and the `~/.local/bin/herdr-app` link pointing into it, and asks `[y/N]` (`--yes` moves it without asking; without a TTY it is kept, with a warning). The core (`~/.local/share/herdr-core`, `herdr-core`, `hc`) stays. While Herdr app is running nothing is removed: quit it and run `./dots update` again. The Nerd Font cask stays declared whatever you select (any terminal needs it, and `./dots font` installs it without Ghostty).

#### Unchecking

Unchecking uninstalls, but only a component that was **recorded** as selected: the first selection on an existing machine (nothing recorded) removes nothing, and neither does a component you never checked. `./dots components` (picker or `<id>...|none`) lists exactly what will be removed and asks `[y/N]` (default No). Declining or cancelling changes nothing and exits non-zero; `--yes` skips the question; without a TTY and without `--yes` the command exits 2 and changes nothing. Checking `herdr-app` implies `herdr-core` on both sides of the comparison. A running official Herdr app (`~/Applications/Herdr.app`) is never removed: those paths are skipped with a warning to quit it first, and the rest of the removal still runs.

| Unchecked | Removed |
|-----------|---------|
| `tmux` | `brew uninstall tmux gitmux` (the installed ones) and the `~/.config/tmux/*` symlinks into this repo |
| `herdr-tui` | `brew uninstall herdr` |
| `herdr-app` | macOS: `brew uninstall --cask herdr-app`, plus an official install (`~/Applications/Herdr.app` and the `~/.local/bin/herdr-app` link into it) when present. Linux: the official install (`${XDG_DATA_HOME:-~/.local/share}/herdr-app`, `~/.local/bin/herdr-app` and the `herdr-app` `.desktop`/icon files) |
| `herdr-core` | `~/.local/bin/herdr-core` and `~/.local/bin/hc` when they are regular files or symlinks (otherwise a warning); never while `herdr-app` stays selected |
| Herdr config | the `~/.config/herdr/config.toml` link, only when no Herdr component remains |
| `ghostty` | macOS: `brew uninstall --cask ghostty`; the `~/.config/ghostty` `config`, `shaders` and `themes/dots` links into this repo (`font.conf` and any other file stay) |

Only symlinks that point into this repo are removed. A package that is not installed is skipped; a failing `brew uninstall` warns and the rest continues, the exit code is non-zero and the new selection is still recorded. Nothing outside the listed paths is touched.

If `@themux_theme` does not refresh in an active tmux session after a switch, run `tmux kill-server` (heavy) or restart tmux manually.

## How it works

- **Symlinks via dotbot**: `config/install.conf.yaml` declares every base file under `content/home/` as a `link:` entry. `./install` runs dotbot which creates symlinks in `$HOME`. Edits in `$HOME` write through to the repo via the symlinks.
- **Zsh via XDG/ZDOTDIR**: `~/.zshenv` is the only zsh startup file kept at `$HOME`; it sets the XDG base dirs and `ZDOTDIR=$XDG_CONFIG_HOME/zsh`, so zsh reads `.zprofile` and `.zshrc` from `~/.config/zsh`. History lives under `~/.local/state/zsh`, and compinit cache under `~/.cache/zsh`.
- **Theme symlinks**: each theme switch re-links per-app theme files and updates the local manifest.
- **Tmux theme**: `content/home/.config/tmux/tmux.conf` sets themux's `@themux_theme` from `$DOTS_THEME` — machine-local state in `~/.config/zsh/local.zsh` whose `theme_flavor` values match themux theme names — falling back to a tracked default. The theme switcher updates the running tmux server's environment and re-sources the config; the repo file never changes.
- **Starship fence**: `content/home/.config/starship.toml` is a base symlink holding every theme's `[palettes.<theme>_<flavor>]` table plus a `dots:theme` fence selecting the active `palette`. The theme switcher rewrites that line in place — no per-theme symlink (Starship has no external-theme include).
- **Herdr fence**: `content/home/.config/herdr/config.toml` is a base symlink. The theme switcher maps the active dots theme to Herdr's built-in theme name, rewrites the fenced `theme.name`, and reloads a running Herdr server. Changing settings from Herdr's own UI rewrites the file and replaces the symlink with a regular file; `./dots doctor` flags it — copy the new settings into the repo before `./dots update` re-links it.
- **Manifest**: `manifest.json` (in `.gitignore`) records `{version, theme, flavor, prompt, applied_at}`. Local-only state.
- **Brewfile + Mise**: `brew bundle --file=config/Brewfile` and `mise install` run as dotbot directives during `./install`. Update them via `./dots upgrade`.

## Adding a new theme

1. Add the asset files under `content/assets/palettes/<app>/<theme>/<flavor>.<ext>` for every app.
2. Create `content/themes/<theme>-<flavor>.yaml` mirroring an existing one.
3. Add the pair to `content/themes/index.yaml`.
4. Test with `./dots theme <theme> <flavor>`.

## Adding a mise tool

Edit `content/home/.config/mise/config.toml`:

```toml
[tools]
node = "lts"
python = "3.12"
```

Run `./dots update` to install. Run `./dots upgrade` to prune removed versions.

## Development

```sh
brew install bats-core shellcheck
make -f config/Makefile lint   # shellcheck (severity warning): dots, src/install, own *.sh; skips vendor/
make -f config/Makefile test   # bats tests/ — fails when bats is not installed
```

Run both before every push; the suite is written for macOS and runs all of it there.

CI (`.github/workflows/ci.yml`) runs the same two targets on a pull request to `main` and by hand (`workflow_dispatch`), never again after the merge. It skips draft pull requests (open them as drafts, mark ready once local runs are green), pull requests that only change `odd/`, `README.md`, `AGENTS.md` or `CLAUDE.md`, and cancels a run when a newer push supersedes it. It runs on Ubuntu to spend fewer Actions minutes, so the tests that drive a PTY with BSD `script` skip there; start a manual run with the `macos-15` runner to cover them.

### Run the CI locally

```sh
pnpm install              # once: the dev tool (@jals1212/ci-local), nothing else
pnpm exec ci-local --list # the plan, without running it
pnpm exec ci-local        # shellcheck + bats in a Linux container (needs Docker)
```

`ci-local.config.sh` runs the steps of `.github/workflows/ci.yml` (the same two `make` targets) in a Linux runner (`docker/ci-local/Dockerfile`: Node of `.nvmrc`, bats, zsh, shellcheck) with this checkout mounted, so `vendor/` is what your submodules hold: run `git submodule update --init --recursive` first (the run checks it). Everything it creates is named `dotfiles-ci-*` (`CI_PROJECT`; the repo directory is `.dotfiles`, but Docker names cannot start with a dot) and nothing publishes a port. The first run builds the image.

- **Proves:** shellcheck and the bats suite pass on Linux (Debian, bats 1.8) against your working tree, uncommitted changes included, like the GitHub job. The tests that drive a PTY with BSD `script` skip there, as on GitHub's Ubuntu runner: macOS (`make -f config/Makefile test` on your machine) covers them.
- **Does not prove:** it makes no GitHub check green, and it is not Ubuntu 24.04 or the `macos-15` runner.
- **Stands in for GitHub** only when the GitHub run failed before any test ran, for infrastructure reasons: then a full run (no `--only`/`--skip`) on the pull request's head commit, clean checkout, recorded in a PR comment. Any lint or test failure on GitHub still blocks the merge.
- **Parity:** `tests/ci_local_parity.bats` (skipped without `pnpm install`) fails when the plan's commands, or the project name `dotfiles-ci`, drift from the workflow. GitHub's run does not install Node, so the check is local: run it after editing either file.
- Upgrade the tool with `pnpm add -D @jals1212/ci-local@latest` (it is in `minimumReleaseAgeExclude` of `pnpm-workspace.yaml` by name), then run the parity test and a full run.

## Documentation

- [Install guide](docs/install.md) — install, update, theme, doctor, clean, upgrade, uninstall.
- [Tools](docs/tools.md) — common usage for managed CLI tools.
- [Aliases](docs/aliases.md) — shell aliases and functions.
- [Plugins](docs/plugins.md) — zsh/tmux plugin usage.
- [Keymaps](docs/keymaps.md) — Neovim, tmux, Ghostty, AeroSpace shortcuts.
- [Themes](docs/themes.md) — theme switching and supported flavors.

## After Install

```sh
exec zsh
./dots doctor
```

Then open tmux: the first start installs the tmux plugins at their pinned commits (see [Plugins](docs/plugins.md#pinned-versions)).

## License

MIT © 2026 Jeffrey León ([@jals1212](https://github.com/jals1212)) — see [LICENSE](LICENSE).
