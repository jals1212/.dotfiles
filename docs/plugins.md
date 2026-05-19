# Plugins

Plugin managers and the curated list each one loads. Nvim plugins are not covered here (one-per-file under `home/.config/nvim/lua/plugins/`).

## Zsh — Zinit

Manager: [Zinit](https://github.com/zdharma-continuum/zinit). Self-installs to `~/.local/share/zinit/zinit.git` on first run if missing. Load order in [`.zshrc`](../home/.zshrc) is intentional — completions before `compinit`, fzf-tab before widget-wrappers, syntax highlighting last.

Per-load command reference: [`zinit` commands](https://github.com/zdharma-continuum/zinit#documentation).

### Completion source

- [`zsh-users/zsh-completions`](https://github.com/zsh-users/zsh-completions) — extra completion definitions. Loaded **before** `compinit` so generated functions are picked up.

### Completion UI

- [`Aloxaf/fzf-tab`](https://github.com/Aloxaf/fzf-tab) — replaces the default zsh tab UI with an fzf picker. Loads after `compinit` and before widget wrappers. Use `Tab` to fuzz over completion candidates.

### Conditional integrations (load only when binary present)

Loaded via `zinit ice has"<bin>"` against the custom shims in [`home/.config/zsh/plugins/`](../home/.config/zsh/plugins).

- [Oh My Posh](https://ohmyposh.dev/) — `oh-my-posh init zsh --config ...`. Prompt renderer; theme lives at `~/.config/oh-my-posh/config.json`.
- [Zoxide](https://github.com/ajeetdsouza/zoxide) — `zoxide init zsh`. Adds `z` / `zi` jump commands.
- [Mise](https://mise.jdx.dev/) — `mise activate zsh`. Polyglot runtime manager (Node, Python, Go, …).
- [Atuin](https://docs.atuin.sh/) — `atuin init zsh --disable-ai`. Replaces zsh history with SQLite-backed search. Adds an `fzf-atuin-history-widget` bound to `Ctrl-P` over Atuin's `Up` and `Ctrl-R` bindings.

### Oh My Zsh snippets

Loaded as snippets so we get the OMZ plugin without dragging in OMZ itself. Each link below points at the plugin's README.

- [`git`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git) — large catalogue of `g`-prefixed aliases (`gst`, `gco`, `gp`, `gl`, `gd`, `grb`, …). Skim the README for the full list.
- [`extract`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/extract) — `extract <archive>` (alias `x`) handles tar/zip/7z/rar/etc.
- [`safe-paste`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/safe-paste) — pasted multi-line text is held for review before execution.
- [`copypath`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/copypath) — `copypath` copies the cwd (or a path) to the clipboard.
- [`copyfile`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/copyfile) — `copyfile <path>` copies the file contents to the clipboard.
- [`copybuffer`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/copybuffer) — `Ctrl-O` copies the current command line.
- [`fancy-ctrl-z`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/fancy-ctrl-z) — `Ctrl-Z` from the prompt foregrounds the last suspended job (one keystroke instead of `fg`).
- [`jsontools`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/jsontools) — `pp_json`, `is_json`, `urlencode_json`, `urldecode_json` helpers.
- [`gh`](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/gh) — completion for the [GitHub CLI](https://cli.github.com/).

### Widget-wrapping plugins

These wrap zle widgets, so they MUST load after `compinit`, fzf-tab, and any custom widgets.

- [`zsh-users/zsh-autosuggestions`](https://github.com/zsh-users/zsh-autosuggestions) — inline ghost-text suggestions from history. Accept with `→` or `End`.
- [`zsh-users/zsh-syntax-highlighting`](https://github.com/zsh-users/zsh-syntax-highlighting) — live command-line syntax colouring. Must be the last `zinit light` to wrap everything else.

## tmux — TPM

Manager: [TPM](https://github.com/tmux-plugins/tpm). Self-installs to `~/.config/tmux/plugins/tpm` on first run. Install/refresh from inside tmux with `prefix + I` (`Ctrl-a I`). Source: [`tmux.conf`](../home/.config/tmux/tmux.conf).

- [`tmux-plugins/tmux-sensible`](https://github.com/tmux-plugins/tmux-sensible) — sane defaults (focus-events, history-limit, fast escape, …).
- [`tmux-plugins/tmux-yank`](https://github.com/tmux-plugins/tmux-yank) — copy mode selections go to the system clipboard.
- [`christoomey/vim-tmux-navigator`](https://github.com/christoomey/vim-tmux-navigator) — `Ctrl-h/j/k/l` traverses Vim splits and tmux panes seamlessly.
- [`tmux-plugins/tmux-resurrect`](https://github.com/tmux-plugins/tmux-resurrect) — save/restore tmux state (`prefix + Ctrl-s` save, `prefix + Ctrl-r` restore).
- [`tmux-plugins/tmux-continuum`](https://github.com/tmux-plugins/tmux-continuum) — runs resurrect on a timer + auto-restore on tmux start (`@continuum-restore on`).
- [`alexwforsythe/tmux-which-key`](https://github.com/alexwforsythe/tmux-which-key) — popup menu describing prefix bindings (trigger with `prefix + Space`).
- [`Nybkox/tmux-ukiyo`](https://github.com/Nybkox/tmux-ukiyo) — theme engine. Flavor comes from `DOTS_THEME_FLAVOR` (rewritten by `./dots apply`). Switch interactively with `prefix + T`. Status modules: `git`, `cpu-usage`, `ram-usage`.

## Ghostty and AeroSpace

Neither uses a plugin manager — all behaviour is in their respective config files. Keybindings in [keymaps.md](keymaps.md).
