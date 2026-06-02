# Plugins

Usage notes for the shell and tmux plugins enabled by these dotfiles. For editor mappings, see [keymaps.md](keymaps.md#neovim).

## Zsh plugins

These load automatically in new shells after `./dots update` has been applied. Restart the shell with `exec zsh` if you just changed settings.

### Completions and picker UI

- Extra completions: press `Tab` after a command to complete more tools and options.
- fzf-tab: `Tab` opens a fuzzy completion picker when multiple choices are available.

### Prompt, navigation, and history

- [Starship](https://starship.rs/) renders the prompt. The active theme is the `palette` selected inside `~/.config/starship.toml`'s `dots:theme` fence; switch with `./dots theme <theme> <flavor>` (takes effect on the next prompt).
- [Zoxide](https://github.com/ajeetdsouza/zoxide) adds smart directory jumps:
  - `z <partial>` jumps to a frequently used matching directory.
  - `zi` opens an interactive picker.
- [Mise](https://mise.jdx.dev/) manages project runtimes:
  - `mise use node@lts`
  - `mise install`
  - `mise ls`
- [Atuin](https://docs.atuin.sh/) powers shell history search:
  - `Up` searches session history.
  - `Ctrl-R` opens global history search.
  - `Ctrl-P` opens history search through fzf.

### Editing assistance

- [zsh-abbr](https://github.com/olets/zsh-abbr) expands abbreviations before commands run:
  - `abbr add gco='git checkout'`
  - Type `gco` then `Space` to expand it in place.
  - Run `abbr help` for more commands.
  - Configured Git abbreviations include `gst`, `gco`, `gcb`, `gcmsg`, `gd`, `gds`, `gl`, `gp`, `gpsup`, `grbi`, `gstp`, and `gswc`.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) shows ghost-text suggestions from history. Accept with `→` or `End`.
- [zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) colors commands as you type so missing commands and invalid syntax stand out early.

## tmux plugins

Open tmux with `tx` or `tmux`, then install or refresh plugins with `Ctrl-a I`.

- [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) — safer defaults.
- [tmux-yank](https://github.com/tmux-plugins/tmux-yank) — copy mode selections go to the system clipboard.
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) — `Ctrl-h/j/k/l` moves across Neovim splits and tmux panes.
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) — `Ctrl-a Ctrl-s` saves tmux state; `Ctrl-a Ctrl-r` restores it.
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) — periodically saves state and restores it on tmux start.
- [tmux-which-key](https://github.com/alexwforsythe/tmux-which-key) — `Ctrl-a Space` opens a binding helper popup.
- [tmux-ukiyo](https://github.com/Nybkox/tmux-ukiyo) — theme engine. Change the managed theme with `./dots update`; switch interactively with `Ctrl-a T` when available.

## Ghostty and AeroSpace

Ghostty and AeroSpace do not need plugin commands. Their shortcuts are listed in [keymaps.md](keymaps.md).
