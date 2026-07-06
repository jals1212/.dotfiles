# Dotfiles — Plugins
# Everything zinit loads, in one place. Plugins load eagerly: turbo raced
# with p10k's async gitstatus redraw and garbled the first prompt. Order:
# completions+compinit → fzf-tab → widget wrappers.

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
zinit light zsh-users/zsh-completions
_dots_compinit
zinit cdreplay -q

# CLI tool integrations (zoxide, mise)
zinit snippet "$ZDOTDIR/tools.zsh"

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit light Aloxaf/fzf-tab

# Abbreviations — all session-scoped, declared in abbr.zsh. Do NOT point
# ABBR_USER_ABBREVIATIONS_FILE here: that var is zsh-abbr's own managed store
# (it rewrites it on any non-session add/erase), which would clobber abbr.zsh.
zinit light olets/zsh-abbr
[[ -f "$ZDOTDIR/abbr.zsh" ]] && source "$ZDOTDIR/abbr.zsh"

# Widget-wrapping plugins load last; eager load lets autosuggestions start
# from its own precmd hook.
zinit light zsh-users/zsh-autosuggestions

zinit light zsh-users/zsh-syntax-highlighting
