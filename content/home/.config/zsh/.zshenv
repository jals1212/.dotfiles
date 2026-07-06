# Dotfiles — Environment
# Runs for every zsh invocation (scripts included); keep it light.

# XDG
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ZDOTDIR
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# Tools
export MISE_DATA_DIR="${XDG_DATA_HOME}/mise"
export MISE_CACHE_DIR="${XDG_CACHE_HOME}/mise"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="bat --paging=always"
export MANPAGER="sh -c 'col -bx | bat -l man -p'"

# Machine-local state (DOTS_PROMPT, DOTS_THEME, ...) written by ./dots.
# A real file in $HOME — never symlinked, never tracked by the repo.
[[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
