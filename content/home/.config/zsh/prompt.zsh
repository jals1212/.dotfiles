# Dotfiles — Prompt
# The engine choice is machine-local: `./dots prompt <engine>` records it as
# DOTS_PROMPT in $ZDOTDIR/local.zsh (sourced from .zshenv, never tracked by
# the repo). Setting DOTS_PROMPT in the environment overrides it per shell.

if [[ "${DOTS_PROMPT:-starship}" == "p10k" ]] && (( $+functions[zinit] )); then
    zinit ice ver"a0c9dbe80be404ff58e3ce5d7cf312582e370635" # pinned, see plugins.zsh
    zinit light romkatv/powerlevel10k
    [[ -f "$ZDOTDIR/p10k.zsh" ]] && source "$ZDOTDIR/p10k.zsh"
else
    # starship: a Homebrew binary, initialized directly and guarded by command
    # presence so startup never errors when it is absent. Its init script is
    # cached by _dots_init_cache (functions.zsh) and rebuilt when the binary
    # changes; without a usable cache it is evaluated live.
    if (( $+commands[starship] )); then
        if (( $+functions[_dots_init_cache] )) && _dots_init_cache starship '' starship init zsh; then
            source "$REPLY"
        else
            eval "$(starship init zsh)"
        fi
    fi
fi
