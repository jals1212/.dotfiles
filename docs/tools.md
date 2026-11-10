# Tools

Brief usage for each managed CLI tool. Nvim covered separately. Tool-specific keybindings are in [keymaps.md](keymaps.md).

## Shell and prompt

### Zsh + Zinit

Login shell with completions and history search. Plugin inventory: [plugins.md](plugins.md).

**Init cache.** zoxide, mise and starship generate their zsh init script at startup. `_dots_init_cache` (in `functions.zsh`) keeps each in `$XDG_CACHE_HOME/zsh/init-<tool>.zsh` so a new shell sources a file instead of forking the tool (about 40 ms of a 0.28 s start on the author's Mac). A cache is rebuilt when the tool binary changes (command path, resolved path, inode, size, mtime), and a truncated or foreign file is ignored in favour of the live `eval`. mise is cached only in a shell that inherits no mise state (`MISE_SHELL`, `__MISE_*` unset): its script embeds the current `PATH`, which the cache rewrites to read the PATH of the shell that sources it. A change to mise *settings* that alters its script is not detected; delete `init-mise.zsh`. `DOTS_INIT_CACHE=0` turns the cache off. `tools.zsh` is sourced, not a `zinit snippet`: zinit serves its own stale copy of a snippet until `zinit update`.

### Starship — [docs](https://starship.rs/)

Prompt renderer (Homebrew binary, initialized from the ZDOTDIR `.zshrc`). Config at `~/.config/starship.toml`; the active theme is the `palette` selected inside its `dots:theme` fence, which `./dots theme <theme> <flavor>` rewrites in place (all per-theme palettes live in that one file). Starship re-reads its config each prompt, so no `exec zsh` is needed.

### Zoxide — [docs](https://github.com/ajeetdsouza/zoxide)

Smarter `cd`. Learns frecency. Usage: `z <partial>` jumps to a frecent dir; `zi` opens an fzf picker over the database. Replaces `cd` for repeated paths.

### Mise — [docs](https://mise.jdx.dev/)

Polyglot runtime/version manager (Node, Python, Go, etc.). Activated in zsh. Common: `mise use node@lts`, `mise install`, `mise ls`. Project pinning via `.mise.toml` or `.tool-versions`.

## Terminal and multiplexer

### Ghostty — [docs](https://ghostty.org/docs)

Terminal emulator, installed only when `ghostty` is selected with `./dots components` (macOS cask; the config is linked on any OS once selected, and `./dots doctor` skips its checks when unselected or on Linux). Splits and resize bindings documented in [keymaps.md](keymaps.md#ghostty). Theme managed by `./dots update`. Font chosen with `./dots font` (`jetbrains-mono` by default, or `iosevka`), written to `~/.config/ghostty/font.conf`. When `herdr-app` is selected the same choice is also written as `font` in `~/.config/herdr-app/settings.json` (Herdr app reloads it live; other keys are kept; needs `jq` or `python3`).

### tmux — [docs](https://github.com/tmux/tmux/wiki)

Multiplexer, installed with gitmux only when `tmux` is selected with `./dots components` (config linked, theme reloaded and doctor checks run only then). Prefix `Ctrl-a`. Use `tx` to attach to or create the main session. Plugin inventory in [plugins.md](plugins.md#tmux-plugins). Full key table: [keymaps.md](keymaps.md#tmux). Aliases for session management: `tx`, `txa`, `txl`, `txk` (see [aliases.md](aliases.md)).

### Herdr

Agent workspace multiplexer. Config: `~/.config/herdr/config.toml`. Prefix: `Ctrl-a`; agent panel sorted by spaces. Theme follows `./dots theme` through the fenced `theme.name` setting. Each Herdr piece is opt-in with `./dots components`: `herdr-tui` (the `herdr` formula), `herdr-core` (Herdr's official core installer, `https://releases.herdr.dev/core/install.sh`, macOS and Linux; skipped when `herdr-core` is already installed, and on Linux when the app is selected; Homebrew has no core package) and `herdr-app` (the `herdr-app` cask on macOS Apple silicon, which brings no core; `./dots update` first moves an official `~/Applications/Herdr.app` install out, after asking; on Linux the official app installer `https://releases.herdr.dev/app/install.sh`, which brings the core). The app is a separate program built on herdr-core and does not share agents with the TUI. The config is linked and the theme fence applied when any Herdr component is selected. The installers are unpinned and a failure only warns; `./dots update` and the targeted install of `./dots components` both run them through `content/home/.config/dots/herdr-install.sh`.

### AeroSpace — [docs](https://nikitabobko.github.io/AeroSpace/guide)

Tiling window manager (macOS). Owns the `ctrl-alt` namespace. Workspaces, layout cycling, service mode in [keymaps.md](keymaps.md#aerospace). Config: `~/.config/aerospace/aerospace.toml`.

## Editors

### VSCodium — [docs](https://vscodium.com/)

GUI editor (macOS cask). `./install` uses `duti` to register VSCodium (`com.vscodium`) as the default app for code and text files, from `~/.config/duti/vscodium.duti`; `.html` and `.xml` are left to their existing handlers. Re-apply manually with `duti ~/.config/duti/vscodium.duti`. Terminal `$EDITOR`/`$VISUAL` stay `nvim`.

A Finder Quick Action, **Open in VSCodium** (right-click a file or folder → Quick Actions), is linked to `~/Library/Services/Open in VSCodium.workflow`. If it does not show up right away, run `/System/Library/CoreServices/pbs -flush`.

## File viewing and listing

### bat — [docs](https://github.com/sharkdp/bat)

`cat` with syntax highlighting and paging. Aliased to `cat`. Theme deployed to `~/.config/bat/themes/dots.tmTheme` and selected by `~/.config/bat/config`. Useful flags: `--style=plain`, `--language=md`, `-A` (show non-printable). `bat cache --build` runs automatically during `update` when bat is present. On Debian/Ubuntu the binary is `batcat`: the zsh config uses it under that name (`DOTS_BAT`) and aliases `bat` to it; see [Linux status](install.md#linux-status) for the cache step.

### eza — [docs](https://eza.rocks/)

Modern `ls`. Aliased to `ls`, `ll`, `la`, `lt`. Icons + group-dirs-first by default. Color shell snippet sourced from `~/.config/eza/theme.sh`.

### fd — [docs](https://github.com/sharkdp/fd)

Fast user-friendly `find`. Aliased to `find`. Common: `fd <pattern>`, `fd -e ts -x prettier -w`, `fd -H` (hidden). Drives `FZF_DEFAULT_COMMAND`. On Debian/Ubuntu the binary is `fdfind`: the zsh config uses it under that name (`DOTS_FD`) and aliases `fd` to it.

### ripgrep (rg) — [docs](https://github.com/BurntSushi/ripgrep)

Fast recursive grep. Aliased to `grep`. `rg <pat>`, `rg -tlua 'symbol'`, `rg -l --files-with-matches`.

### jq — [docs](https://jqlang.org/manual/)

JSON processor. Use globally with `<cmd> J '.field'` (global alias `J='| jq'`). Standalone: `jq '.[] | .name' file.json`.

### jless — [docs](https://jless.io/)

TUI JSON browser. Suffix-aliased: open with `file.json` (suffix alias). Direct: `jless file.json`. Navigation: vim keys, `e/c` expand/collapse.

## Fuzzy finding

### fzf — [docs](https://junegunn.github.io/fzf/)

Fuzzy finder with previews on `Ctrl-T` (files) and `Alt-C` (directories). `Ctrl-R` opens fzf's own history search; `Up` opens a custom one — see [aliases.md](aliases.md#shell-keybindings). tmux pickers live at prefix `f` (sessions) and prefix `w` (session/window tree).

## Git and docker

### OrbStack — [docs](https://docs.orbstack.dev/)

Local container runtime. Start it with `orb start` and stop it with `orb stop`. OrbStack activates the `orbstack` Docker context automatically, so no global `DOCKER_HOST` is needed.

### Docker CLI — [docs](https://docs.docker.com/reference/cli/docker/)

OrbStack provides and updates Docker, Compose, and Buildx. Verify them with `docker version`, `docker compose version`, and `docker buildx version` after starting OrbStack.

### Git + hub — [git docs](https://git-scm.com/doc) · [hub docs](https://hub.github.com/)

`hub` extends `git` with GitHub commands and is aliased to `git`. Examples: `git pr list`, `git clone owner/repo` (shorthand), `git browse`. Falls back to plain git for unknown subcommands.

### LazyGit — [docs](https://github.com/jesseduffield/lazygit)

Git TUI. Aliased to `lg`. Theme written to `~/.config/lazygit/config.yml`. Common actions: stage hunks with `Space`, commit with `c`, push with `P`, log with `l`.

### LazyDocker — [docs](https://github.com/jesseduffield/lazydocker)

Docker/Compose TUI. Aliased to `ld`. Mirrors lazygit's panel/key model over containers, images, volumes, networks.

## System and monitoring

### bottom (btm) — [docs](https://clementtsang.github.io/bottom/)

System monitor. Aliased to `top`. Theme at `~/.config/bottom/bottom.toml`. Toggle widgets with `Tab`, freeze with `f`, kill process with `dd`.

### dust — [docs](https://github.com/bootandy/dust)

`du` alternative with bar visualization. Aliased to `du`. `dust -d 3` for depth limit; `dust -r` reverse sort.

### gping — [docs](https://github.com/orf/gping)

Graphical ping with throughput chart. Aliased to `ping`. `gping host1 host2` to compare.

## Misc

TUI primitives used by `./dots`: no external dependency. `./dots` ships its own POSIX sh pickers (`tui_choose`), confirms (`tui_confirm`) and cards (`tui_card`) in `src/lib/tui.sh` (↑↓/jk move, enter selects, q or esc cancels).

## Themes

Theme deployment covered in [themes.md](themes.md). Switch theme with `./dots theme <family> <flavor>` (or `./dots update --yes --theme=<family> --flavor=<flavor>` to also rerun the base config).
