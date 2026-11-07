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
- fzf powers shell history search:
  - `Ctrl-R` opens fzf's own history widget.
  - `Up` opens a custom fzf history widget (deduplicated, query seeded from the current line).
  - `Ctrl-P` / `Ctrl-N` step inline through matching history entries (no fzf).

### Editing assistance

- [zsh-abbr](https://github.com/olets/zsh-abbr) expands abbreviations before commands run:
  - `abbr add gco='git checkout'`
  - Type `gco` then `Space` to expand it in place.
  - Run `abbr help` for more commands.
  - Configured Git abbreviations include `gst`, `gco`, `gcb`, `gcmsg`, `gd`, `gds`, `gl`, `gp`, `gpsup`, `grbi`, `gstp`, and `gswc`.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) shows ghost-text suggestions from history. Accept with `→` or `End`.
- [fast-syntax-highlighting](https://github.com/zdharma-continuum/fast-syntax-highlighting) colors commands as you type so missing commands and invalid syntax stand out early.

## tmux plugins

Open tmux with `tx` or `tmux`: the first start clones TPM and every plugin below, each at a pinned commit.

### Pinned versions

Like the zsh plugins (`zsh/plugins.zsh`), every tmux plugin, TPM included, is pinned to an exact commit. TPM can only follow a branch (`owner/repo#branch`), so the pin lives in `content/home/.config/tmux/tmux.conf`: a `# pin <sha>` line directly above each `set -g @plugin` line. `scripts/pin-plugins.sh` (run by `tmux.conf` before TPM loads anything) clones a missing plugin and checks out the pin when a checkout sits on another commit; a checkout already on its pin is left alone.

- **Bump one:** replace its sha with a newer upstream commit (review the diff first), then reload with `tmux source ~/.config/tmux/tmux.conf` or restart tmux.
- **Add one:** add a `# pin <sha>` line and the `set -g @plugin 'owner/repo'` line below it. `tests/dependency_pins.bats` fails when an `@plugin` has no pin.
- **`Ctrl-a U` (TPM update)** moves a plugin off its pin until the next reload re-pins it; do not rely on it. `Ctrl-a I` installs only what `pin-plugins.sh` has not.
- **Fails closed:** the script exits 1 and prints one `pin-plugins:` line per problem; tmux still starts. A plugin it just cloned whose pin cannot be checked out is removed again, so TPM never loads unpinned code; an existing checkout is kept. It also reports an `@plugin` line it cannot parse (accepted: `set` or `set-option -g @plugin 'owner/repo'`, single or double quotes, leading whitespace, trailing `# comment`), an `@plugin` without a valid `# pin <40-hex>` line above it, and a name that is not a plain `owner/repo` (`[A-Za-z0-9._-]` only, no `..`; `owner/repo#branch` is refused).
- **Offline:** a plugin already on its pin needs no network; a missing one is reported as `cannot clone` and tmux starts without it.

- [tmux-sensible](https://github.com/tmux-plugins/tmux-sensible) — safer defaults.
- [tmux-yank](https://github.com/tmux-plugins/tmux-yank) — copy mode selections go to the system clipboard.
- [vim-tmux-navigator](https://github.com/christoomey/vim-tmux-navigator) — `Ctrl-h/j/k/l` moves across Neovim splits and tmux panes.
- [tmux-resurrect](https://github.com/tmux-plugins/tmux-resurrect) — `Ctrl-a Ctrl-s` saves tmux state; `Ctrl-a Ctrl-r` restores it.
- [tmux-continuum](https://github.com/tmux-plugins/tmux-continuum) — periodically saves state and restores it on tmux start.
- [tmux-which-key](https://github.com/alexwforsythe/tmux-which-key) — `Ctrl-a Space` opens a binding helper popup.
- [themux](https://github.com/jals1212/themux) — theme engine. Reads the active theme from `$DOTS_THEME` via `@themux_theme`; change it with `./dots theme`.

## Ghostty and AeroSpace

Ghostty and AeroSpace do not need plugin commands. Their shortcuts are listed in [keymaps.md](keymaps.md).
