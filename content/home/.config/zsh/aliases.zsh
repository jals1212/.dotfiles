# Dotfiles — Aliases

# Modern replacements (flag-incompatible ones — cd/find/grep — are
# abbreviations in abbr.zsh, so the real command stays one edit away)
alias cat='bat'
alias du='dust'
alias la='eza -la --icons --group-directories-first'
alias ll='eza -l --icons --group-directories-first'
alias ls='eza --icons --group-directories-first'
alias lt='eza -T --icons --level=2'
alias ping='gping'
alias top='btm'

# Portable `open` (Linux uses xdg-open; macOS has open natively)
[[ "$(uname)" != "Darwin" ]] && command -v xdg-open >/dev/null 2>&1 && alias open='xdg-open'

# Shortcuts
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias -- -='cd -'
alias dotfiles='$EDITOR ~/.dotfiles' # the dots command is a function — see functions.zsh
alias fp='fzf --preview="bat --theme=dots --color=always {}"'
alias j='z'
alias jj='zi'
alias ld='lazydocker'
alias lg='lazygit'

# Globals
alias -g J='| jq' # Pipe to jq
alias -g NE='2>/dev/null' # Redirect stderr to /dev/null
alias -g NO='>/dev/null' # Redirect stdout to /dev/null
alias -g NUL='>/dev/null 2>&1' # Redirect both stdout and stderr to /dev/null
# Copy output to clipboard (cross-platform)
if [[ "$(uname)" == "Darwin" ]]; then
  alias -g C='| pbcopy'
elif command -v wl-copy >/dev/null 2>&1; then
  alias -g C='| wl-copy'                      # Wayland
elif command -v xclip >/dev/null 2>&1; then
  alias -g C='| xclip -selection clipboard'   # X11
fi

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
