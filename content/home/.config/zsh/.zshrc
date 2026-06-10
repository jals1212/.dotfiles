# Dotfiles - ZSH

# Plugin manager
[[ -f "$ZDOTDIR/zinit.zsh" ]] && source "$ZDOTDIR/zinit.zsh"

# History
HISTFILE="${XDG_STATE_HOME}/zsh/history"
HISTSIZE=50000
SAVEHIST=50000
[[ -d "${HISTFILE:h}" ]] || command mkdir -p "${HISTFILE:h}"
setopt append_history
setopt extended_history
setopt hist_ignore_all_dups
setopt hist_ignore_space
setopt hist_reduce_blanks
setopt share_history

# User commands and base keymaps load before plugins can add/wrap widgets.
[[ -f "$ZDOTDIR/aliases.zsh" ]]   && source "$ZDOTDIR/aliases.zsh"
[[ -f "$ZDOTDIR/functions.zsh" ]] && source "$ZDOTDIR/functions.zsh"
[[ -f "$ZDOTDIR/keymaps.zsh" ]]   && source "$ZDOTDIR/keymaps.zsh"

# Tool-owned shell entrypoints
[[ -f "${XDG_CONFIG_HOME}/fzf/config.zsh" ]] && source "${XDG_CONFIG_HOME}/fzf/config.zsh"
[[ -f "${XDG_CONFIG_HOME}/eza/config.zsh" ]] && source "${XDG_CONFIG_HOME}/eza/config.zsh"

# Prompt is eager (the first prompt needs it); plugins load deferred.
[[ -f "$ZDOTDIR/prompt.zsh" ]]  && source "$ZDOTDIR/prompt.zsh"
[[ -f "$ZDOTDIR/plugins.zsh" ]] && source "$ZDOTDIR/plugins.zsh"
