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

