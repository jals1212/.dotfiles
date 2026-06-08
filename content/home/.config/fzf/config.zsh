# Dotfiles — fzf

if command -v fd >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="fd --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="fd --type d --hidden --strip-cwd-prefix --exclude .git"
fi

[[ -f "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/theme.sh" ]] && source "${XDG_CONFIG_HOME:-$HOME/.config}/fzf/theme.sh"

if command -v fzf >/dev/null 2>&1; then
    source <(fzf --zsh)
fi

# _dots_fzf_history_widget() {
#     local selected
#     local -a fzf_opts

#     fzf_opts=(
#         --layout=reverse
#         --border=top
#         --info=inline
#         --no-sort
#         --cycle
#         --query="$LBUFFER"
#         --prompt="History > "
#     )

#     if [[ -n "${TMUX:-}" || -n "${ZELLIJ:-}" ]]; then
#         fzf_opts=(--popup=top,100%,45% "${fzf_opts[@]}")
#     else
#         fzf_opts=(--height="${FZF_HISTORY_HEIGHT:-45%}" "${fzf_opts[@]}")
#     fi

#     selected=$(
#         fc -l -n -r 1 |
#             awk 'NF && !seen[$0]++' |
#             fzf "${fzf_opts[@]}"
#     ) || return

#     LBUFFER="$selected"
#     RBUFFER=""
#     zle reset-prompt
# }

# if [[ -o interactive ]] && command -v fzf >/dev/null 2>&1; then
#     zle -N _dots_fzf_history_widget
#     bindkey '^R' _dots_fzf_history_widget
#     bindkey '^P' _dots_fzf_history_widget
#     bindkey '^[[A' _dots_fzf_history_widget
#     [[ -n "${terminfo[kcuu1]:-}" ]] && bindkey "${terminfo[kcuu1]}" _dots_fzf_history_widget
# fi

true
