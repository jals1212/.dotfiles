# Dotfiles — Aliases

# Dotfiles
alias dots='~/.dotfiles/dots'
alias dotfiles='$EDITOR ~/.dotfiles'

# Globals
alias -g NE='2>/dev/null' # Redirect stderr to /dev/null
alias -g NO='>/dev/null' # Redirect stdout to /dev/null
alias -g NUL='>/dev/null 2>&1' # Redirect both stdout and stderr to /dev/null
alias -g J='| jq' # Pipe to jq
# Copy output to clipboard (cross-platform)
if [[ "$(uname)" == "Darwin" ]]; then
  alias -g C='| pbcopy'
elif command -v wl-copy >/dev/null 2>&1; then
  alias -g C='| wl-copy'                      # Wayland
elif command -v xclip >/dev/null 2>&1; then
  alias -g C='| xclip -selection clipboard'   # X11
fi

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
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias lg='lazygit'
alias ld='lazydocker'

# Portable `open` (Linux uses xdg-open; macOS has open natively)
[[ "$(uname)" != "Darwin" ]] && command -v xdg-open >/dev/null 2>&1 && alias open='xdg-open'

# Suffixes
alias -s csv='$EDITOR'
alias -s go='$EDITOR'
alias -s html=open
alias -s js='$EDITOR'
alias -s json=jless
alias -s log=bat
alias -s md=bat
alias -s py='$EDITOR'
alias -s rs='$EDITOR'
alias -s ts='$EDITOR'
alias -s txt=bat
alias -s yaml='$EDITOR'
alias -s yml='$EDITOR'

# FZF previews
alias fzfbat='fzf --preview="bat --theme=dots --color=always {}"'
alias fzfnvim='nvim $(fzf --preview="bat --theme=dots --color=always {}")'
