# Dotfiles — Prompt
# The engine choice is machine-local: `./dots prompt <engine>` records it as
# DOTS_PROMPT in $ZDOTDIR/local.zsh (sourced from .zshenv, never tracked by
# the repo). Setting DOTS_PROMPT in the environment overrides it per shell.

if [[ "${DOTS_PROMPT:-starship}" == "p10k" ]] && (( $+functions[zinit] )); then
    zinit ice depth=1
    zinit light romkatv/powerlevel10k
    [[ -f "$ZDOTDIR/p10k.zsh" ]] && source "$ZDOTDIR/p10k.zsh"
else
    # starship: a Homebrew binary, initialized directly and guarded by command
    # presence so startup never errors when it is absent.
    command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
fi
