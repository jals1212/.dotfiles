# Dotfiles — Plugins
# Everything zinit loads, in one place. All plugins are deferred (turbo) to
# just after the first prompt; wait slots keep the required order:
# completions+compinit (0a) → fzf-tab (0b) → widget wrappers (0c).

(( $+functions[zinit] )) || return

# compinit with a daily security audit: a fresh dump (<20h) is trusted and
# loaded with -C (skips the expensive audit); an old or missing dump triggers
# a full rebuild. The dump is zcompiled in the background so later shells map
# the compiled form instead of re-parsing it.
_dots_compinit() {
    setopt local_options extended_glob
    local dump="${XDG_CACHE_HOME}/zsh/zcompdump-${ZSH_VERSION}"
    [[ -d "${dump:h}" ]] || command mkdir -p "${dump:h}"
    autoload -Uz compinit
    if [[ -n ${dump}(#qN.mh-20) ]]; then
        compinit -C -d "$dump"
    else
        compinit -d "$dump"
    fi
    { [[ -s "$dump" && ( ! -s "${dump}.zwc" || "$dump" -nt "${dump}.zwc" ) ]] && zcompile "$dump" } &!
}

# Completion definitions must be loaded before compinit. cdreplay re-applies
# compdef calls plugins issued before compinit existed.
zinit ice wait"0a" lucid atload"_dots_compinit; zinit cdreplay -q"
zinit light zsh-users/zsh-completions

# CLI tool integrations (zoxide, mise)
zinit ice wait"0a" lucid
zinit snippet "$ZDOTDIR/tools.zsh"

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit ice wait"0b" lucid
zinit light Aloxaf/fzf-tab

# Abbreviations — all session-scoped, declared in abbr.zsh. Do NOT point
# ABBR_USER_ABBREVIATIONS_FILE here: that var is zsh-abbr's own managed store
# (it rewrites it on any non-session add/erase), which would clobber abbr.zsh.
zinit ice wait"0b" lucid atload'[[ -f "$ZDOTDIR/abbr.zsh" ]] && source "$ZDOTDIR/abbr.zsh"'
zinit light olets/zsh-abbr

# Widget-wrapping plugins load after compinit, fzf-tab, and custom widgets.
# Autosuggestions normally starts from a precmd hook that has already fired
# by the time turbo loads it, so start it explicitly.
zinit ice wait"0c" lucid atload"_zsh_autosuggest_start"
zinit light zsh-users/zsh-autosuggestions

zinit ice wait"0c" lucid
zinit light zsh-users/zsh-syntax-highlighting
