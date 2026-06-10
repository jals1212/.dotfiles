# Dotfiles — Completions

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

# Completion definitions must be loaded before compinit; both are deferred to
# just after the first prompt (turbo slot 0a). cdreplay re-applies compdef
# calls plugins issued before compinit existed.
zinit ice wait"0a" lucid atload"_dots_compinit; zinit cdreplay -q"
zinit light zsh-users/zsh-completions

# fzf-tab must load after compinit, but before widget-wrapping plugins (0b).
zinit ice wait"0b" lucid
zinit light Aloxaf/fzf-tab
