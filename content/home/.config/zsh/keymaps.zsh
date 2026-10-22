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

# Home/End (Ghostty maps cmd+left/right to these so ^A stays the herdr prefix)
bindkey '\e[H' beginning-of-line
bindkey '\e[F' end-of-line
bindkey '\eOH' beginning-of-line
bindkey '\eOF' end-of-line

# Ctrl-P/Ctrl-N: inline stepping through history entries matching what's typed.
# Up/Ctrl-R fzf widgets live in fzf/config.zsh, not here.
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^P' up-line-or-beginning-search    # Ctrl-P
bindkey '^N' down-line-or-beginning-search  # Ctrl-N
