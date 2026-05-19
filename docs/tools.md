# Tools

Brief usage for each managed CLI tool. Nvim covered separately. Source list: [`Brewfile`](../Brewfile). Tool-specific keybindings already documented in [keymaps.md](keymaps.md).

## Shell and prompt

### Zsh + Zinit

Login shell. Plugin manager [Zinit](https://github.com/zdharma-continuum/zinit) loads completions, history search, and OMZ snippets. Repo-owned fragments live under `home/.config/zsh/` and are sourced from `~/.zshrc`. Inventory in [plugins.md](plugins.md).

### Oh My Posh — [docs](https://ohmyposh.dev/)

Prompt renderer. Theme JSON deployed to `~/.config/oh-my-posh/config.json` by `./dots apply`. Switch flavors via `./dots select`. Reload: `exec zsh`.

### Atuin — [docs](https://docs.atuin.sh/)

History DB (sqlite) replacing native zsh history. Bindings:

- `Up` — session history (Atuin's shell-up).
- `Ctrl-R` — global search (Atuin's default).
- `Ctrl-P` — global search piped through fzf (repo widget, see `home/.config/zsh/plugins/atuin/atuin.plugin.zsh`).

`atuin search <query>` for CLI search. `atuin stats` for usage report. Config: `~/.config/atuin/config.toml`.

### Zoxide — [docs](https://github.com/ajeetdsouza/zoxide)

Smarter `cd`. Learns frecency. Usage: `z <partial>` jumps to a frecent dir; `zi` opens an fzf picker over the database. Replaces `cd` for repeated paths.

### Mise — [docs](https://mise.jdx.dev/)

Polyglot runtime/version manager (Node, Python, Go, etc.). Activated in zsh. Common: `mise use node@lts`, `mise install`, `mise ls`. Project pinning via `.mise.toml` or `.tool-versions`.

## Terminal and multiplexer

### Ghostty — [docs](https://ghostty.org/docs)

Terminal emulator (macOS cask). Config: `~/.config/ghostty/config`. Splits and resize bindings documented in [keymaps.md](keymaps.md#ghostty). Theme block managed by `./dots apply`. Cursor smear shader at `home/.config/ghostty/shaders/cursor_smear.glsl`.

### tmux — [docs](https://github.com/tmux/tmux/wiki)

Multiplexer. Prefix `Ctrl-a`. Sessions auto-start via `start_if_needed` in `.zshrc`. Plugin inventory in [plugins.md](plugins.md#tmux-tpm). Full key table: [keymaps.md](keymaps.md#tmux). Aliases for session management: `tx`, `txa`, `txl`, `txk` (see [aliases.md](aliases.md)).

### AeroSpec / AeroSpace — [docs](https://nikitabobko.github.io/AeroSpace/guide)

Tiling window manager (macOS). Owns the `ctrl-alt` namespace. Workspaces, layout cycling, service mode in [keymaps.md](keymaps.md#aerospace). Config: `~/.config/aerospace/aerospace.toml`.

## File viewing and listing

### bat — [docs](https://github.com/sharkdp/bat)

`cat` with syntax highlighting and paging. Aliased to `cat`. Theme deployed to `~/.config/bat/themes/dots.tmTheme` and exported as `BAT_THEME=dots`. Useful flags: `--style=plain`, `--language=md`, `-A` (show non-printable). `bat cache --build` runs automatically on apply when bat is present.

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

Fuzzy finder. Drives `Ctrl-T` (files), `Alt-C` (dirs), `Ctrl-R` (when Atuin disabled), and several repo-defined widgets. Custom command vars in `.zshrc` use `fd`. Tmux pickers at prefix `f` (sessions) and prefix `w` (windows). Aliases `fzfbat` / `fzfnvim` for previewed pickers.

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

TUI primitives (input, choose, confirm, spin) used by `./dots select` for the wizard. Standalone usage: `gum choose a b c`, `gum input --prompt 'name: '`.

## Themes

Theme deployment covered in [themes.md](themes.md). Override flavor with `./dots select` or `./bootstrap.sh --yes --theme=<family> --flavor=<flavor>`.
