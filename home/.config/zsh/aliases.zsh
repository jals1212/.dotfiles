# Dotfiles — Aliases

# Globals
alias -g NE='2>/dev/null' # Redirect stderr to /dev/null
alias -g NO='>/dev/null' # Redirect stdout to /dev/null
alias -g NUL='>/dev/null 2>&1' # Redirect both stdout and stderr to /dev/null
alias -g J='| jq' # Pipe to jq
alias -g C='| pbcopy' # Copy output to clipboard (macOS)
# alias -g C='| xclip -selection clipboard' # Copy output to clipboard (Linux with xclip)

# Modern replacements
alias ls='eza --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias la='eza -la --icons --group-directories-first'
alias lt='eza -T --icons --level=2'
alias cat='bat'
alias grep='rg'
alias find='fd'
alias du='dust'
alias top='btm'
alias ping='gping'
alias git='hub'

# Shortcuts
alias c='clear'
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias vim='nvim'
alias v='nvim'
alias lg='lazygit'
alias ld='lazydocker'

# Suffixes
alias -s csv='$EDITOR'
alias -s go='$EDITOR'
alias -s html=open
alias -s js='$EDITOR'
alias -s json=jless
alias -s log=bat
alias -s md='$EDITOR'
alias -s md=bat
alias -s py='$EDITOR'
alias -s rs='$EDITOR'
alias -s ts='$EDITOR'
alias -s txt=bat
alias -s yaml='$EDITOR'
alias -s yml='$EDITOR'

# Tmux
alias tx='tmux new-session -A -s main'
alias txa='tmux attach -t'
alias txl='tmux ls'
alias txk='tmux kill-session -t'

# Dotfiles
alias dots='cd ~/.dotfiles && nvim'
alias dotsync='~/.dotfiles/dots'

# FZF previews
alias fzfbat='fzf --preview="bat --theme=dots --color=always {}"'
alias fzfnvim='nvim $(fzf --preview="bat --theme=dots --color=always {}")'
