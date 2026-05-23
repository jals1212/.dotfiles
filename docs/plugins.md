# Plugins

Usage notes for the shell and tmux plugins enabled by these dotfiles. For editor mappings, see [keymaps.md](keymaps.md#neovim).

## Zsh plugins

These load automatically in new shells after `./dots update` has been applied. Restart the shell with `exec zsh` if you just changed settings.

### Completions and picker UI

- Extra completions: press `Tab` after a command to complete more tools and options.
- fzf-tab: `Tab` opens a fuzzy completion picker when multiple choices are available.

### Prompt, navigation, and history

- [Oh My Posh](https://ohmyposh.dev/) renders the prompt. Change prompt flavor with `./dots update`, then reload with `exec zsh`.
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

### Oh My Zsh helpers

These helpers are available without installing the full Oh My Zsh framework.

- [`git`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git) — `g`-prefixed aliases like `gst`, `gco`, `gp`, `gl`, `gd`, and `grb`.
- [`extract`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/extract) — `extract <archive>` or `x <archive>` extracts common archive formats.
- [`safe-paste`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/safe-paste) — reviews pasted multi-line commands before execution.
- [`copypath`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/copypath) — `copypath` copies the current directory or a path.
- [`copyfile`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/copyfile) — `copyfile <path>` copies file contents.
- [`copybuffer`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/copybuffer) — `Ctrl-O` copies the current command line.
- [`fancy-ctrl-z`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/fancy-ctrl-z) — `Ctrl-Z` at an empty prompt brings back the last suspended job.
- [`jsontools`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/jsontools) — `pp_json`, `is_json`, `urlencode_json`, and `urldecode_json`.
- [`gh`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/gh) — GitHub CLI completion.

### Editing assistance

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
