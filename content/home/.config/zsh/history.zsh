# Dotfiles — History

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
