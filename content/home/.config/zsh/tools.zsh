# Dotfiles — CLI tool integrations
# Sourced (eagerly) from plugins.zsh, after compinit.

# The init scripts of zoxide, mise and starship are cached by _dots_init_cache
# (functions.zsh): a new shell sources a file instead of forking each tool, and
# the cache is rebuilt when the tool binary changes. Without the helper, or when
# it reports no usable cache, the init is evaluated live as before.

# Zoxide
if (( $+commands[zoxide] )); then
    if (( $+functions[_dots_init_cache] )) && _dots_init_cache zoxide '' zoxide init zsh; then
        source "$REPLY"
    else
        eval "$(zoxide init zsh)"
    fi
fi

# Mise
# `mise activate` prints the current PATH (twice) and, in a shell that inherits
# an activated mise, a cleanup prelude built from that state. A cache must not
# freeze either: it is used only in a clean shell (no mise state inherited), and
# the PATH it printed is rewritten to read the PATH of the shell that sources it.
# mise also adds its own directory to PATH when it is missing; mise is found on
# PATH here, so it is generated as present and that line never appears.
# A change to mise *settings* that alters the script is not detected (the key is
# the binary and its data dir): delete $XDG_CACHE_HOME/zsh/init-mise.zsh.
_dots_mise_activate() {
    local marker=/__dots_path_sentinel__ out fake
    fake=${commands[mise]:h}:$marker
    out=$(PATH=$fake $commands[mise] activate zsh) || return 1
    local -r live='"$PATH"'   # the text the sourced cache evaluates
    out=${out//"'$fake'"/$live}
    out=${out//":$fake'"/:\'$live}
    out=${out//"=$fake"/"=$live"}
    [[ $out == *$marker* ]] && return 1
    print -r -- $out
}
if (( $+commands[mise] )); then
    if (( ! ${+MISE_SHELL} && ! ${+__MISE_SESSION} && ! ${+__MISE_DIFF} && ! ${+__MISE_ORIG_PATH} )) &&
        (( $+functions[_dots_init_cache] )) &&
        _dots_init_cache mise "$MISE_DATA_DIR|$XDG_DATA_HOME|$HOME" _dots_mise_activate; then
        source "$REPLY"
    else
        eval "$(mise activate zsh)"
    fi
    # `mise activate` registers a per-prompt env refresh (~50ms each prompt).
    # Directory changes are the only trigger we need — the chpwd hook stays,
    # and the activate script already applied the starting directory's env.
    # Trade-off: after `mise use` or editing a mise.toml, the current shell
    # keeps the old env until the next `cd` (or run `cd .`).
    autoload -Uz add-zsh-hook
    add-zsh-hook -d precmd _mise_hook_precmd 2>/dev/null
fi
unfunction _dots_mise_activate

# tmux — redraw the status line on directory change so cwd-dependent modules
# (gitmux, directory) update immediately instead of waiting out status-interval.
if [[ -n "$TMUX" ]]; then
    autoload -Uz add-zsh-hook
    _tmux_status_refresh() { tmux refresh-client -S 2>/dev/null }
    add-zsh-hook chpwd _tmux_status_refresh
fi
