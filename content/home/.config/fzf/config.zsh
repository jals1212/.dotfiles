# Dotfiles — fzf

# DOTS_BAT / DOTS_FD: batcat / fdfind on Debian/Ubuntu (resolved in zsh/.zshenv).
if command -v "${DOTS_FD:-fd}" >/dev/null 2>&1; then
    export FZF_DEFAULT_COMMAND="${DOTS_FD:-fd} --type f --hidden --strip-cwd-prefix --exclude .git"
    export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
    export FZF_ALT_C_COMMAND="${DOTS_FD:-fd} --type d --hidden --strip-cwd-prefix --exclude .git"
fi

[[ -f "${XDG_CONFIG_HOME}/fzf/theme.sh" ]] && source "${XDG_CONFIG_HOME}/fzf/theme.sh"

# UI defaults appended after the theme (theme.sh overwrites FZF_DEFAULT_OPTS).
export FZF_DEFAULT_OPTS="$FZF_DEFAULT_OPTS --height=60% --layout=reverse --border=rounded --preview-window=right:65%:wrap:border-left"

# Previews: bat for Ctrl-T files, eza tree for Alt-C directories.
export FZF_CTRL_T_OPTS="--preview '${DOTS_BAT:-bat} --theme=dots --color=always --style=plain,numbers --line-range=:500 {}'"
export FZF_ALT_C_OPTS="--preview 'eza --tree --icons --color=always --level=2 {}'"

if command -v fzf >/dev/null 2>&1; then
    # fzf-tab (plugins.zsh) owns Tab; load only key-bindings here, skipping
    # the completion module and the `fzf --zsh` subprocess. Falls back if absent.
    _fzf_keys="${HOMEBREW_PREFIX:-/opt/homebrew}/opt/fzf/shell/key-bindings.zsh"
    if [[ -r "$_fzf_keys" ]]; then
        source "$_fzf_keys"
    else
        source <(fzf --zsh)
    fi
    unset _fzf_keys
fi

# Up-only history widget (Ctrl-R stays on fzf's own above); deduped, seeded from $LBUFFER.
_dots_fzf_history_widget() {
    local selected
    local -a fzf_opts

    fzf_opts=(
        --layout=default
        --border=top
        --info=inline
        --no-sort
        --cycle
        --query="$LBUFFER"
        --prompt="History > "
    )

    if [[ -n "${TMUX:-}" || -n "${ZELLIJ:-}" ]]; then
        fzf_opts=(--popup=top,100%,45% "${fzf_opts[@]}")
    else
        fzf_opts=(--height="${FZF_HISTORY_HEIGHT:-45%}" "${fzf_opts[@]}")
    fi

    selected=$(
        fc -l -n -r 1 |
            awk 'NF && !seen[$0]++' |
            fzf "${fzf_opts[@]}"
    ) || return

    LBUFFER="$selected"
    RBUFFER=""
    zle reset-prompt
}

if [[ -o interactive ]] && command -v fzf >/dev/null 2>&1; then
    zle -N _dots_fzf_history_widget
    bindkey '^[[A' _dots_fzf_history_widget
    [[ -n "${terminfo[kcuu1]:-}" ]] && bindkey "${terminfo[kcuu1]}" _dots_fzf_history_widget
fi

# Clean exit status guard (repo convention; see eza/config.zsh).
true
