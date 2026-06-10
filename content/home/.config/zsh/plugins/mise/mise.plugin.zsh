# Dotfiles — Mise integration

eval "$(mise activate zsh)"

# `mise activate` registers a per-prompt env refresh (~50ms each prompt).
# Directory changes are the only trigger we need — the chpwd hook stays, and
# the activate script already applied the starting directory's env once.
autoload -Uz add-zsh-hook
add-zsh-hook -d precmd _mise_hook_precmd 2>/dev/null
