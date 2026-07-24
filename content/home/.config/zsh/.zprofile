# Dotfiles — ZSH
# Login shell environment setup: Homebrew + PATH.

typeset -U path PATH

_dots_brew_shellenv() {
  local brew_bin
  if [[ "$(uname)" == "Darwin" ]]; then
    for brew_bin in /opt/homebrew/bin/brew /usr/local/bin/brew; do
      if [[ -x "$brew_bin" ]]; then
        eval "$("$brew_bin" shellenv)"
        return
      fi
    done
  elif [[ -x /home/linuxbrew/.linuxbrew/bin/brew ]]; then
    eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
  fi
}

_dots_brew_shellenv
unfunction _dots_brew_shellenv 2>/dev/null || true

path=(
  "$HOME/.local/bin"
  $path
)

if [[ -r "$HOME/.local/bin/env" ]]; then
  source "$HOME/.local/bin/env"
fi

typeset -U path PATH
export PATH

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :
