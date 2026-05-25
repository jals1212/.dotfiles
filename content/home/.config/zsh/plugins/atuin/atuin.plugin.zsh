# Dotfiles — Atuin integration

eval "$(atuin init zsh --disable-ai)"

# History search:
#   Up     -> session history, via Atuin's shell-up binding
#   Ctrl-R -> global history, via Atuin's default search binding
#   Ctrl-P -> global history, using fzf as the picker over Atuin history
function fzf-atuin-history-widget() {
  local selected
  selected=$(
    atuin search --cmd-only --limit "${ATUIN_FZF_LIMIT:-5000}" |
      fzf --height="${ATUIN_FZF_HEIGHT:-80%}" \
          --layout=reverse \
          --tac \
          --query="$LBUFFER" \
          --prompt="Atuin global > "
  ) || return

  LBUFFER="$selected"
  RBUFFER=""
  zle reset-prompt
}

if command -v fzf >/dev/null 2>&1; then
  zle -N fzf-atuin-history-widget
  bindkey '^p' fzf-atuin-history-widget
fi
