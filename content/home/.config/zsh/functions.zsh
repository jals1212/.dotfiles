# Dotfiles — Functions

# Dotfiles

# Wrapper over the dots script: a child process cannot exec its parent shell,
# so reload-after-change lives here. When the script drops a reload marker
# (prompt/theme changes that only apply to new shells), offer an exec zsh.
dots() {
    ~/.dotfiles/dots "$@"
    local ret=$?
    local marker="$XDG_STATE_HOME/dots/reload-needed"
    if (( ret == 0 )) && [[ -f "$marker" && -o interactive && -t 0 && -t 1 ]]; then
        command rm -f -- "$marker"
        local _reply
        read -q "_reply?Reload shell to apply changes? [y/N] " && { print; exec zsh; }
        print
    fi
    return $ret
}

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

# Global npm CLIs live in mise (npm: backend; see mise/config.toml). A global
# `npm i -g` lands in the active node's lib/node_modules, whose bin comes first
# in PATH, so it silently shadows mise's copy and is lost on a Node change.
# Refuse global installs, updates and links; `command npm` skips this check.
npm() {
    local arg verb global=0 next_location=0
    for arg in "$@"; do
        if (( next_location )); then
            [[ $arg == global ]] && global=1
            next_location=0
            continue
        fi
        case $arg in
            -g|--global|--location=global) global=1 ;;
            --location) next_location=1 ;;
            -*) ;;
            *) [[ -z $verb ]] && verb=$arg ;;
        esac
    done
    case $verb in
        i|in|ins|inst|insta|instal|install|isnt|isnta|isntal|isntall|add|update|up|upgrade|udpate|link|ln)
            if (( global )); then
                print -u2 "npm: global packages live in mise: mise use -g npm:<package> (command npm skips this check)"
                return 1
            fi
            ;;
    esac
    command npm "$@"
}

# Remote agents (Tailscale + Moshi)

# Wrapper over `moshi-hook host setup`: Easy Pair appends a fresh SSH key to
# authorized_keys with no restrictions, so every pairing silently reopens the
# "any tailnet node can log in" hole. The daemon also reads its pairing only at
# startup, so a pairing done while it runs leaves it in socket-only mode with no
# remote approvals and no visible error. Both fixes must follow every pairing.
moshi-pair() {
    local harden="$HOME/.config/remote-agents/harden-authorized-keys.sh"

    if [[ ! -x "$harden" ]]; then
        print -u2 "moshi-pair: missing or non-executable $harden"
        print -u2 "moshi-pair: refusing to pair without the hardening step"
        return 1
    fi

    command moshi-hook host setup "$@" || return $?

    print
    print "--- re-applying SSH key restrictions ---"
    "$harden" || {
        print -u2 "moshi-pair: hardening FAILED - your key may be unrestricted"
        print -u2 "moshi-pair: inspect ~/.ssh/authorized_keys before relying on this host"
        return 1
    }

    print
    print "--- restarting moshi-hook daemon ---"
    launchctl kickstart -k "gui/$(id -u)/sh.brew.moshi-hook" || {
        print -u2 "moshi-pair: daemon restart failed - notifications may not arrive"
        return 1
    }

    # The daemon reports pairing from the keychain even when the running process
    # has no HostID, so verify against its runtime log instead of `status`.
    sleep 2
    local log="$HOME/Library/Application Support/Moshi/hook.log"
    if grep -q 'ws bridge connected' <(tail -n 20 "$log" 2>/dev/null); then
        print "moshi-pair: OK - key restricted and daemon bridge connected"
    else
        print -u2 "moshi-pair: WARNING - no 'ws bridge connected' in the recent log"
        print -u2 "moshi-pair: check with: tail -f '$log'"
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
