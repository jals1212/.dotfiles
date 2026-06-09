# Dotfiles — Keybindings

# Emacs mode
bindkey -e

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

# History: inline contextual stepping on Ctrl-P / Ctrl-N through entries
# beginning with the text already typed. Up and Ctrl-R open the fzf history
# widget instead (see fzf/config.zsh).
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^P' up-line-or-beginning-search    # Ctrl-P
bindkey '^N' down-line-or-beginning-search  # Ctrl-N
