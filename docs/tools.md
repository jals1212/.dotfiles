# Tools

Brief usage for each managed CLI tool. Nvim covered separately. Tool-specific keybindings are in [keymaps.md](keymaps.md).

## Shell and prompt

### Zsh + Zinit

Login shell with completions and history search. Plugin inventory: [plugins.md](plugins.md).

### Starship — [docs](https://starship.rs/)

Prompt renderer (Homebrew binary, initialized in `.zshrc`). Config at `~/.config/starship.toml`; the active theme is the `palette` selected inside its `dots:theme` fence, which `./dots theme <theme> <flavor>` rewrites in place (all per-theme palettes live in that one file). Starship re-reads its config each prompt, so no `exec zsh` is needed.

### Zoxide — [docs](https://github.com/ajeetdsouza/zoxide)

Smarter `cd`. Learns frecency. Usage: `z <partial>` jumps to a frecent dir; `zi` opens an fzf picker over the database. Replaces `cd` for repeated paths.

### Mise — [docs](https://mise.jdx.dev/)

Polyglot runtime/version manager (Node, Python, Go, etc.). Activated in zsh. Common: `mise use node@lts`, `mise install`, `mise ls`. Project pinning via `.mise.toml` or `.tool-versions`.

## Terminal and multiplexer

### Ghostty — [docs](https://ghostty.org/docs)

Terminal emulator (macOS cask). Splits and resize bindings documented in [keymaps.md](keymaps.md#ghostty). Theme managed by `./dots update`.

### tmux — [docs](https://github.com/tmux/tmux/wiki)

Multiplexer. Prefix `Ctrl-a`. Use `tx` to attach to or create the main session. Plugin inventory in [plugins.md](plugins.md#tmux-plugins). Full key table: [keymaps.md](keymaps.md#tmux). Aliases for session management: `tx`, `txa`, `txl`, `txk` (see [aliases.md](aliases.md)).

### AeroSpace — [docs](https://nikitabobko.github.io/AeroSpace/guide)

Tiling window manager (macOS). Owns the `ctrl-alt` namespace. Workspaces, layout cycling, service mode in [keymaps.md](keymaps.md#aerospace). Config: `~/.config/aerospace/aerospace.toml`.

## File viewing and listing

### bat — [docs](https://github.com/sharkdp/bat)

`cat` with syntax highlighting and paging. Aliased to `cat`. Theme deployed to `~/.config/bat/themes/dots.tmTheme` and exported as `BAT_THEME=dots`. Useful flags: `--style=plain`, `--language=md`, `-A` (show non-printable). `bat cache --build` runs automatically during `update` when bat is present.

### eza — [docs](https://eza.rocks/)

Modern `ls`. Aliased to `ls`, `ll`, `la`, `lt`. Icons + group-dirs-first by default. Color shell snippet sourced from `~/.config/eza/themes/dots.sh`.

### fd — [docs](https://github.com/sharkdp/fd)

Fast user-friendly `find`. Aliased to `find`. Common: `fd <pattern>`, `fd -e ts -x prettier -w`, `fd -H` (hidden). Drives `FZF_DEFAULT_COMMAND`.

### ripgrep (rg) — [docs](https://github.com/BurntSushi/ripgrep)

Fast recursive grep. Aliased to `grep`. `rg <pat>`, `rg -tlua 'symbol'`, `rg -l --files-with-matches`.

### jq — [docs](https://jqlang.org/manual/)

JSON processor. Use globally with `<cmd> J '.field'` (global alias `J='| jq'`). Standalone: `jq '.[] | .name' file.json`.

### jless — [docs](https://jless.io/)

TUI JSON browser. Suffix-aliased: open with `file.json` (suffix alias). Direct: `jless file.json`. Navigation: vim keys, `e/c` expand/collapse.

## Fuzzy finding

### fzf — [docs](https://junegunn.github.io/fzf/)

Fuzzy finder. Drives shell history search with `Ctrl-R` and `Ctrl-P`, plus file/directory pickers when available. tmux pickers live at prefix `f` (sessions) and prefix `w` (windows). Aliases `fzfbat` / `fzfnvim` open previewed pickers.

## Git and docker

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

### gum — [docs](https://github.com/charmbracelet/gum)

TUI primitives used by `./dots`: `gum choose` for the action menu and update wizard pickers, `gum confirm` for update approval, `gum style` for picker headers/summary/success boxes, and `gum format` for future formatted terminal blocks. Standalone usage: `gum choose a b c`, `gum style --border rounded 'done'`, `gum input --prompt 'name: '`.

## Themes

Theme deployment covered in [themes.md](themes.md). Switch theme with `./dots theme <family> <flavor>` (or `./dots update --yes --theme=<family> --flavor=<flavor>` to also rerun the base config).
