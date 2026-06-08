# Dotfiles — Completions

(( $+functions[zinit] )) || return

# Completion definitions must be loaded before compinit.
zinit light zsh-users/zsh-completions

autoload -Uz compinit && compinit
zinit cdreplay -q

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit light Aloxaf/fzf-tab
