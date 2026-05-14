# Dotfiles — ZSH Profile
# Environment & PATH setup

# ── Homebrew ─────────────────────────────────────────
if [[ "$(uname)" == "Darwin" ]]; then
  eval "$(/opt/homebrew/bin/brew shellenv 2>/dev/null || /usr/local/bin/brew shellenv 2>/dev/null)"
elif [[ -d /home/linuxbrew/.linuxbrew ]]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
fi

# ── Starship ─────────────────────────────────────────
export STARSHIP_CONFIG="${XDG_CONFIG_HOME:-$HOME/.config}/starship/starship.toml"

# ── Mise ─────────────────────────────────────────────
export MISE_DATA_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/mise"
export MISE_CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/mise"

# ── PATH ─────────────────────────────────────────────
export PATH="$HOME/.local/bin:$HOME/.dotfiles/bin:$PATH"

# ── XDG ──────────────────────────────────────────────
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"
export XDG_DATA_HOME="${XDG_DATA_HOME:-$HOME/.local/share}"
export XDG_CACHE_HOME="${XDG_CACHE_HOME:-$HOME/.cache}"

# ── Default apps ─────────────────────────────────────
export EDITOR="nvim"
export VISUAL="nvim"
export PAGER="bat --paging=always"