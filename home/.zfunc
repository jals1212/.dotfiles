# Dotfiles — Functions

# cd to Finder's current directory (macOS)
cdf() {
  local curr_path
  curr_path=$(osascript -e 'tell application "Finder" to if (count of Finder windows) > 0 then get POSIX path of (target of front Finder window as text)')
  if [[ -n "$curr_path" ]]; then
    cd "$curr_path" || return
  else
    echo "No Finder window found"
  fi
}

# Universal archive extraction
extract() {
  if [[ -z "$1" ]]; then
    echo "Usage: extract <archive>"
    return 1
  fi
  if [[ ! -f "$1" ]]; then
    echo "File not found: $1"
    return 1
  fi
  case "$1" in
    *.tar.bz2) tar xjf "$1" ;;
    *.tar.gz)  tar xzf "$1" ;;
    *.tar.xz)  tar xJf "$1" ;;
    *.bz2)     bunzip2 "$1" ;;
    *.rar)     unrar x "$1" ;;
    *.gz)      gunzip "$1" ;;
    *.tar)     tar xf "$1" ;;
    *.tbz2)    tar xjf "$1" ;;
    *.tgz)     tar xzf "$1" ;;
    *.zip)     unzip "$1" ;;
    *.Z)       uncompress "$1" ;;
    *.7z)      7z x "$1" ;;
    *)         echo "Unknown format: $1" ;;
  esac
}

# mkdir + cd
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Git commit with message
gcm() {
  git commit -m "$*"
}

# Widgets

# Clear screen but keep current command buffer
function clear-screen-and-scrollback() {
  echoti civis >"$TTY"
  printf '%b' '\e[H\e[2J\e[3J' >"$TTY"
  echoti cnorm >"$TTY"
  zle redisplay
}
zle -N clear-screen-and-scrollback
bindkey '^x^l' clear-screen-and-scrollback

# Copy current command buffer to clipboard (macOS)
function copy-buffer-to-clipboard() {
  echo -n "$BUFFER" | pbcopy
  zle -M "Copied to clipboard"
}
zle -N copy-buffer-to-clipboard
bindkey '^x^c' copy-buffer-to-clipboard

# For Linux with wl-copy:
# function copy-buffer-to-clipboard() {
#   echo -n "$BUFFER" | wl-copy
#   zle -M "Copied to clipboard"
# }

# Snippets

bindkey -s '^x^g' 'git status'
bindkey -s '^x^gc' 'git commit -m ""\C-b'
bindkey -s '^x^gp' 'git push origin '
bindkey -s '^x^gs' 'git status\n'
bindkey -s '^x^gl' 'git log --oneline -n 10\n'
