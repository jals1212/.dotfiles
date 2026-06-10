# Dotfiles — ZSH

# Loads on every shell start. Keep it small: scripts inherit this too.

# XDG
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ZDOTDIR
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

[[ -f "$ZDOTDIR/env.zsh" ]] && source "$ZDOTDIR/env.zsh"
