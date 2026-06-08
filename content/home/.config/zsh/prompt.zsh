# Dotfiles — Prompt

# Starship is a Homebrew binary; initialize directly (no zinit wrapper),
# guarded by command presence so startup never errors when it is absent.
command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
