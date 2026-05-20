# Aliases, functions, and shell keybindings

Shell shortcuts available after applying the dotfiles.

Tool-level keybindings (tmux, Ghostty, AeroSpace, Neovim) live in [keymaps.md](keymaps.md). For the tools themselves see [tools.md](tools.md).

## Global aliases

Zsh expands [global aliases](https://zsh.sourceforge.io/Doc/Release/Shell-Grammar.html#Aliasing) anywhere on the command line, not only the first word. Use as a pipe segment.

- `NE` → `2>/dev/null` — silence stderr (`make build NE`).
- `NO` → `>/dev/null` — silence stdout.
- `NUL` → `>/dev/null 2>&1` — silence both.
- `J` → `| jq` — pipe to [jq](https://jqlang.org/manual/) (`curl ... J '.data'`).
- `C` → `| pbcopy` — copy output to macOS clipboard (`pwd C`). On Linux, use the platform clipboard command instead.

## Modern command replacements

Drop-in aliases that swap classic tools for friendlier alternatives. Full tool docs in [tools.md](tools.md).

- `ls`, `ll`, `la`, `lt` → [`eza`](https://eza.rocks/) with icons + dirs first; `lt` is a 2-level tree.
- `cat` → [`bat`](https://github.com/sharkdp/bat).
- `grep` → [`rg`](https://github.com/BurntSushi/ripgrep).
- `find` → [`fd`](https://github.com/sharkdp/fd).
- `du` → [`dust`](https://github.com/bootandy/dust).
- `top` → [`btm`](https://clementtsang.github.io/bottom/) (bottom).
- `ping` → [`gping`](https://github.com/orf/gping).
- `git` → [`hub`](https://hub.github.com/) (passes through to git for unknown commands).

If you need the original tool, prefix with `\`: `\cat`, `\grep`, `\ls`.

## Shortcuts

- `c` → `clear`.
- `..`, `...`, `....` → climb 1/2/3 levels.
- `vim`, `v` → `nvim`.
- `lg` → [`lazygit`](https://github.com/jesseduffield/lazygit).
- `ld` → [`lazydocker`](https://github.com/jesseduffield/lazydocker).

## Suffix aliases

Zsh runs [suffix aliases](https://zsh.sourceforge.io/Doc/Release/Shell-Grammar.html#Aliasing) when you "execute" a file with that extension. Type `file.ext` (no command) to open it.

- `csv`, `go`, `js`, `md`, `py`, `rs`, `ts`, `yaml`, `yml` → `$EDITOR` (Neovim).
- `html` → `open` (macOS default browser).
- `json` → [`jless`](https://jless.io/).
- `log`, `txt`, `md` → [`bat`](https://github.com/sharkdp/bat). Note `md` is bound twice; last definition (`bat`) wins.

## Tmux helpers

Session quick-management. Prefix is `Ctrl-a` (full key table in [keymaps.md](keymaps.md#tmux)).

- `tx` → `tmux new-session -A -s main` — attach or create the `main` session.
- `txa <name>` → attach to a named session.
- `txl` → list sessions.
- `txk <name>` → kill a session.

## Dotfiles helpers

- `dots` → `cd ~/.dotfiles && nvim` — open the repo in Neovim.
- `dotsync` → run `./dots` from anywhere. Subcommands documented in [install.md](install.md#everyday-commands).

## fzf previews

- `fzfbat` → `fzf` with `bat` preview pane (selection prints the path).
- `fzfnvim` → same picker, opens the choice in Neovim.

## Functions


### `cdf`

macOS-only. `cd` into the directory of the front Finder window. No-op message if no Finder window is open. Uses AppleScript.

### `mkcd <dir>`

`mkdir -p <dir>` then `cd` into it.

### `clear-screen-and-scrollback`

Zle widget bound to `Ctrl-X Ctrl-L`. Clears the visible screen and scrollback buffer while keeping the current command line intact. Native `Ctrl-L` (in zle Emacs mode) only clears the visible screen.

## Shell keybindings

[Zle](https://zsh.sourceforge.io/Doc/Release/Zsh-Line-Editor.html) is in Emacs mode.

- `Alt-w` (`\ew`) → `kill-region` — cut between mark and point.
- `Ctrl-_` (`^_`) → `undo` — undo last edit.
- `Ctrl-X Ctrl-E` → `edit-command-line` — open current buffer in `$EDITOR`.
- `Ctrl-Right` / `Ctrl-Left` → `forward-word` / `backward-word`.
- `Ctrl-X Ctrl-L` → `clear-screen-and-scrollback` (see above).

Additional widget bindings come from plugins (autosuggestions, fzf-tab, Atuin) — see [plugins.md](plugins.md).
