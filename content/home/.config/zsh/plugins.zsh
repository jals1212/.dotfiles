# Dotfiles — Plugins
# Everything zinit loads, in one place. Plugins load eagerly: turbo raced
# with p10k's async gitstatus redraw and garbled the first prompt. Order:
# completions+compinit → fzf-tab → widget wrappers.

(( $+functions[zinit] )) || return

# Pinned plugins: every `zinit light` is preceded by `zinit ice ver"<sha>"`
# so a fresh install gets the exact code reviewed here. To bump one, replace
# its sha with a newer commit from upstream and run `zinit update <user>/<repo>`.

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
zinit ice ver"64f802936cc368202957e1db42e9305eaaddda4d"
zinit light zsh-users/zsh-completions
_dots_compinit
zinit cdreplay -q

# CLI tool integrations (zoxide, mise)
zinit snippet "$ZDOTDIR/tools.zsh"

# fzf-tab must load after compinit, but before widget-wrapping plugins.
zinit ice ver"e394092c17277c84cb3d234917c4ac1073102ba6"
zinit light Aloxaf/fzf-tab

# Abbreviations — all session-scoped, declared in abbr.zsh. Do NOT point
# ABBR_USER_ABBREVIATIONS_FILE here: that var is zsh-abbr's own managed store
# (it rewrites it on any non-session add/erase), which would clobber abbr.zsh.
zinit ice ver"889f4772c12b9dbe4965bbd56f2572af0a28fa3b"
zinit light olets/zsh-abbr
# Every `abbr` call ends with a job-queue pop that forks `rm` even for session
# abbreviations, which never push a job (empty job id) — ~3ms each, ~250ms for
# the whole file. Skip that no-op pop while abbr.zsh loads, then restore.
if [[ -f "$ZDOTDIR/abbr.zsh" ]]; then
    if (( $+functions[job-queue__zsh-abbr] )); then
        functions[_dots_abbr_job_queue]=$functions[job-queue__zsh-abbr]
        job-queue__zsh-abbr() {
            [[ $1 == pop && -z $3 ]] && return 0
            _dots_abbr_job_queue "$@"
        }
        source "$ZDOTDIR/abbr.zsh"
        functions[job-queue__zsh-abbr]=$functions[_dots_abbr_job_queue]
        unfunction _dots_abbr_job_queue
    else
        source "$ZDOTDIR/abbr.zsh"
    fi
fi

# Widget-wrapping plugins load last; eager load lets autosuggestions start
# from its own precmd hook.
zinit ice ver"85919cd1ffa7d2d5412f6d3fe437ebdbeeec4fc5"
zinit light zsh-users/zsh-autosuggestions

zinit ice ver"3d574ccf48804b10dca52625df13da5edae7f553"
zinit light zdharma-continuum/fast-syntax-highlighting
