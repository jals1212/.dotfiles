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

# mkdir + cd
mkcd() {
  mkdir -p "$1" && cd "$1"
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
