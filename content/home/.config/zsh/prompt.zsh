# Dotfiles — Prompt
# The active engine is selected inside the dots:prompt fence, which
# `./dots prompt <engine>` rewrites in place; DOTS_PROMPT overrides it for a
# single shell. Do not edit the fenced line by hand.

# >>> dots:prompt >>>
_dots_prompt_engine="p10k"
# <<< dots:prompt <<<

if [[ "${DOTS_PROMPT:-$_dots_prompt_engine}" == "p10k" ]] && (( $+functions[zinit] )); then
    zinit ice depth=1
    zinit light romkatv/powerlevel10k
    [[ -f "$ZDOTDIR/p10k.zsh" ]] && source "$ZDOTDIR/p10k.zsh"
else
    # starship: a Homebrew binary, initialized directly and guarded by command
    # presence so startup never errors when it is absent.
    command -v starship >/dev/null 2>&1 && eval "$(starship init zsh)"
fi

unset _dots_prompt_engine
