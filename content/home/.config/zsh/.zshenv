# Dotfiles — Environment
# Runs for every zsh invocation (scripts included); keep it light.

# XDG
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_STATE_HOME="${XDG_STATE_HOME:-$HOME/.local/state}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ZDOTDIR
export ZDOTDIR="${ZDOTDIR:-$XDG_CONFIG_HOME/zsh}"

# Debian/Ubuntu install bat and fd as batcat and fdfind. DOTS_BAT / DOTS_FD name
# the command to run: the plain name unless only the Debian one is on PATH.
# Resolved before Homebrew joins PATH below (brew's bat/fd keep their plain
# names); every bat/fd call in these dotfiles goes through them, as a command
# string or an alias, because a shim function would not reach `sh -c` (MANPAGER)
# or fzf's preview subshells.
if (( ! $+commands[bat] && $+commands[batcat] )); then DOTS_BAT=batcat; else DOTS_BAT=bat; fi
if (( ! $+commands[fd] && $+commands[fdfind] )); then DOTS_FD=fdfind; else DOTS_FD=fd; fi

# Homebrew on PATH for non-login shells too (e.g. `ssh host cmd`, herdr-core over SSH from Herdr Mobile)
typeset -U path
[[ -d /opt/homebrew/bin ]] && path=(/opt/homebrew/bin /opt/homebrew/sbin $path)

# Tools
export MISE_DATA_DIR="${XDG_DATA_HOME}/mise"
export MISE_CACHE_DIR="${XDG_CACHE_HOME}/mise"
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="$DOTS_BAT --paging=always"
export MANPAGER="sh -c 'col -bx | $DOTS_BAT -l man -p'"

# Machine-local state (DOTS_PROMPT, DOTS_THEME, ...) written by ./dots.
# A real file in $HOME — never symlinked, never tracked by the repo.
[[ -f "$ZDOTDIR/local.zsh" ]] && source "$ZDOTDIR/local.zsh"
