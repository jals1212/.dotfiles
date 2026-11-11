# Aliases, functions, and shell keybindings

Shell shortcuts available after applying the dotfiles.

Tool-level keybindings (tmux, Ghostty, AeroSpace, Neovim) live in [keymaps.md](keymaps.md). For the tools themselves see [tools.md](tools.md).

## Abbreviations

Abbreviations expand in place before the command runs. Type the short form, then press `Space`.

- `c` → `clear`.
- `cd` → `z`, `find` → `fd`, `grep` → `rg` — expanded visibly, so you can edit the flags (or the command) before running.
- `tx` → `tmux`.
- `txs <name>` → create or attach to a named session.
- `txa <name>` → attach to a named session.
- `txl` → list sessions.
- `txk <name>` → kill a session.
- `hr` → `herdr`.
- `hrr <target>` → attach to a remote Herdr session.
- `hra <name>` → attach to a named Herdr session.
- `hrl` → list Herdr sessions.
- `hrss` → show Herdr server status.
- `hrwl` / `hrwc <label>` → list or create Herdr workspaces.
- `hraa <target>` / `hrta <id>` → attach to an agent or terminal.
- `hrk <name>` / `hrK` → stop a named session or the default server; this exits panes.
- `gsh` → `gentle-shell`; `gshc` / `gshr` continue or pick a Pi session (`-- --continue` / `-- --resume`).
- `gshl` → `gentle-shell --link`; `gshv` → `--version`; `gshh` → `home`; `gshs` → `setup`.
- `gshu` / `gshum` / `gshur` → `upgrade`, `upgrade --channel main`, `upgrade --rollback`.
- Git shortcuts expand to full commands, for example:
  - `gst` → `git status`
  - `gco` → `git checkout`
  - `gcb` → `git checkout -b`
  - `gcmsg` → `git commit --message`
  - `gd` → `git diff`
  - `gds` → `git diff --staged`
  - `gl` → `git pull`
  - `gp` → `git push`
  - `gpsup` → `git push --set-upstream origin HEAD`
  - `grbi` → `git rebase --interactive`
  - `gstp` → `git stash pop`
  - `gswc` → `git switch --create`

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
- `du` → [`dust`](https://github.com/bootandy/dust).
- `top` → [`btm`](https://clementtsang.github.io/bottom/) (bottom).
- `ping` → [`gping`](https://github.com/orf/gping).

`cd`, `find` and `grep` are abbreviations instead (see above): they expand to [`z`](https://github.com/ajeetdsouza/zoxide), [`fd`](https://github.com/sharkdp/fd) and [`rg`](https://github.com/BurntSushi/ripgrep) on `Space`, so pasted commands with classic flags are easy to fix.

If you need the original tool, prefix with `\`: `\cat`, `\ls`.

## Shortcuts

- `..`, `...`, `....` → climb 1/2/3 levels.
- `-` → previous directory (`cd -`).
- `j`, `jj` → [`zoxide`](https://github.com/ajeetdsouza/zoxide) jump (`z`) and interactive pick (`zi`).
- `dotfiles` → open the dots repo (`$DOTS_REPO`, default `~/.dotfiles`) in `$EDITOR`.
- `fp` → `fzf` with a `bat` preview.
- `lg` → [`lazygit`](https://github.com/jesseduffield/lazygit).
- `ld` → [`lazydocker`](https://github.com/jesseduffield/lazydocker).

## Suffix aliases

Zsh runs [suffix aliases](https://zsh.sourceforge.io/Doc/Release/Shell-Grammar.html#Aliasing) when you "execute" a file with that extension. Type `file.ext` (no command) to open it.

- `csv`, `go`, `js`, `py`, `rs`, `ts`, `yaml`, `yml` → `$EDITOR` (Neovim by default; `./dots editor fresh` switches it).
- `html` → `open` (macOS default browser).
- `json` → [`jless`](https://jless.io/).
- `log`, `txt`, `md` → [`bat`](https://github.com/sharkdp/bat).

## Dotfiles helpers

- `dots` → run the dotfiles CLI from anywhere. Subcommands are documented in [install.md](install.md#everyday-commands).
- `dotfiles` → open the repo in `$EDITOR`.

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

Additional widget bindings come from plugins and fzf history search — see [plugins.md](plugins.md).
