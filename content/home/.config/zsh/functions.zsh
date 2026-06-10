# Dotfiles — Functions

# Filesystem

# cd to Finder's current directory (macOS only — relies on osascript/Finder)
if [[ "$(uname)" == "Darwin" ]]; then
  cdf() {
    local curr_path
    curr_path=$(osascript -e 'tell application "Finder" to if (count of Finder windows) > 0 then get POSIX path of (target of front Finder window as text)')
    if [[ -n "$curr_path" ]]; then
      cd "$curr_path" || return
    else
      echo "No Finder window found"
    fi
  }
fi

# mkdir + cd
mkcd() {
  mkdir -p "$1" && cd "$1"
}

# Git

# Delete local branches already merged into HEAD, protecting the current
# branch and the usual long-lived ones. `command grep` bypasses the
# grep->ripgrep alias; 2>/dev/null swallows git's error on empty input.
gbda() {
  git branch --no-color --merged \
    | command grep -vE '^([+*]|\s*(main|master|develop|dev)\s*$)' \
    | command xargs git branch --delete 2>/dev/null
}

# Undo all consecutive --wip-- commits: reset back to the most recent
# non-wip commit (keeps their changes in the working tree). Pairs with the
# gwip / gunwip abbreviations.
gunwipall() {
  local _commit
  _commit=$(git log --grep='--wip--' --invert-grep --max-count=1 --format=format:%H)
  if [[ "$_commit" != "$(git rev-parse HEAD)" ]]; then
    git reset "$_commit" || return 1
  fi
}

# Tmux

# Apps run inside tmux (e.g. Neovim) enable color-scheme change
# notifications (DEC private mode 2031). When a tmux session is killed the
# host terminal emits a `\e[?997;1n` theme report that nothing consumes, so
# it lands in the next prompt as literal `997;1n`. A precmd hook runs too
# late — the bytes are already buffered — so wrap tmux instead: once it
# exits, disable the mode and drain any stray report synchronously, before
# the prompt's line editor reads it.
tmux() {
    command tmux "$@"
    local ret=$?
    if [[ -o interactive && -t 0 ]]; then
        printf '\e[?2031l'                                # stop further reports
        local _discard
        while read -s -t 0.2 -k 1 _discard 2>/dev/null; do :; done  # silently drain
    fi
    return $ret
}

# Start tmux for interactive TTY shells not already inside one.
# Opt out per-shell with DOTS_NO_TMUX=1.
tmux-autostart() {
    if [[ $- == *i* ]] && [[ -z "${TMUX}" ]] && [[ -t 1 ]] && [[ -z "${DOTS_NO_TMUX}" ]]; then
        tmux
    fi
}

# Widgets

# Clear screen but keep current command buffer
clear-screen-and-scrollback() {
  echoti civis >"$TTY"
  printf '%b' '\e[H\e[2J\e[3J' >"$TTY"
  echoti cnorm >"$TTY"
  zle redisplay
}
zle -N clear-screen-and-scrollback
bindkey '^x^l' clear-screen-and-scrollback
