# Dotfiles — CLI tool integrations
# Loaded as a deferred zinit snippet from plugins.zsh.

# Zoxide
(( $+commands[zoxide] )) && eval "$(zoxide init zsh)"

# Mise
if (( $+commands[mise] )); then
    eval "$(mise activate zsh)"
    # `mise activate` registers a per-prompt env refresh (~50ms each prompt).
    # Directory changes are the only trigger we need — the chpwd hook stays,
    # and the activate script already applied the starting directory's env.
    autoload -Uz add-zsh-hook
    add-zsh-hook -d precmd _mise_hook_precmd 2>/dev/null
fi

# tmux — redraw the status line on directory change so cwd-dependent modules
# (gitmux, directory) update immediately instead of waiting out status-interval.
if [[ -n "$TMUX" ]]; then
    autoload -Uz add-zsh-hook
    _tmux_status_refresh() { tmux refresh-client -S 2>/dev/null }
    add-zsh-hook chpwd _tmux_status_refresh
fi
