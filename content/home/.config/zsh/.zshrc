# Dotfiles - ZSH

# Plugin manager and interactive shell state
[[ -f "$ZDOTDIR/zinit.zsh" ]]   && source "$ZDOTDIR/zinit.zsh"
[[ -f "$ZDOTDIR/history.zsh" ]] && source "$ZDOTDIR/history.zsh"

# User commands and base keymaps load before plugins can add/wrap widgets.
[[ -f "$ZDOTDIR/aliases.zsh" ]]   && source "$ZDOTDIR/aliases.zsh"
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"
[[ -f "$ZDOTDIR/keymaps.zsh" ]]   && source "$ZDOTDIR/keymaps.zsh"

# Tool-owned shell entrypoints
[[ -f "${XDG_CONFIG_HOME}/fzf/config.zsh" ]] && source "${XDG_CONFIG_HOME}/fzf/config.zsh"
[[ -f "${XDG_CONFIG_HOME}/eza/config.zsh" ]] && source "${XDG_CONFIG_HOME}/eza/config.zsh"

# Plugin/completion order matters: completions before widget-wrapping plugins.
[[ -f "$ZDOTDIR/completions.zsh" ]] && source "$ZDOTDIR/completions.zsh"
[[ -f "$ZDOTDIR/prompt.zsh" ]]      && source "$ZDOTDIR/prompt.zsh"
[[ -f "$ZDOTDIR/plugins.zsh" ]]     && source "$ZDOTDIR/plugins.zsh"
[[ -f "$ZDOTDIR/tmux.zsh" ]]        && source "$ZDOTDIR/tmux.zsh"
