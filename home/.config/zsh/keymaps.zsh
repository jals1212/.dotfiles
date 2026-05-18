# Dotfiles — Keybindings

# Emacs mode
bindkey -e

# History search with arrow keys
bindkey '^p' history-search-backward
bindkey '^n' history-search-forward

# Kill region
bindkey '\ew' kill-region

# Undo
bindkey '^_' undo

# Edit command line in editor
autoload -z edit-command-line
zle -N edit-command-line
bindkey '^x^e' edit-command-line

# Word movement
bindkey '\e[1;5C' forward-word
bindkey '\e[1;5D' backward-word