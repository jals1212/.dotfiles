# Dotfiles — powerlevel10k
# Lean-style prompt; structure is theme-independent. Per-theme colors live in
# the palette tables below; the active one is named by DOTS_THEME, which
# `./dots theme <theme> <flavor>` records in $ZDOTDIR/local.zsh.

_dots_p10k_palette="${DOTS_THEME:-kanagawa_dragon}"

# Same hex values as the starship.toml palettes (blue mauve green gray red).
typeset -gA _dots_p10k_colors
case "$_dots_p10k_palette" in
    catppuccin_mocha)     _dots_p10k_colors=(blue '#89b4fa' mauve '#cba6f7' green '#a6e3a1' gray '#a6adc8' red '#f38ba8') ;;
    catppuccin_frappe)    _dots_p10k_colors=(blue '#8caaee' mauve '#ca9ee6' green '#a6d189' gray '#a5adce' red '#e78284') ;;
    catppuccin_latte)     _dots_p10k_colors=(blue '#1e66f5' mauve '#8839ef' green '#40a02b' gray '#6c6f85' red '#d20f39') ;;
    catppuccin_macchiato) _dots_p10k_colors=(blue '#8aadf4' mauve '#c6a0f6' green '#a6da95' gray '#a5adcb' red '#ed8796') ;;
    kanagawa_dragon)      _dots_p10k_colors=(blue '#8ba4b0' mauve '#a292a3' green '#8a9a7b' gray '#737c73' red '#c4746e') ;;
    kanagawa_lotus)       _dots_p10k_colors=(blue '#4d699b' mauve '#624c83' green '#6f894e' gray '#a09cac' red '#c84053') ;;
    kanagawa_wave)        _dots_p10k_colors=(blue '#7e9cd8' mauve '#957fb8' green '#76946a' gray '#727169' red '#c34043') ;;
    *)                    _dots_p10k_colors=(blue blue mauve magenta green green gray gray red red) ;;
esac

# Inside tmux the status bar already shows git, so the prompt drops the
# vcs segment and stays minimal.
if [[ -n "$TMUX" ]]; then
    typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir newline prompt_char)
else
    typeset -g POWERLEVEL9K_LEFT_PROMPT_ELEMENTS=(dir vcs newline prompt_char)
fi
typeset -g POWERLEVEL9K_RIGHT_PROMPT_ELEMENTS=(time)

# Lean style: plain text, no powerline backgrounds, no icon padding.
typeset -g POWERLEVEL9K_BACKGROUND=
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_{LEFT,RIGHT}_WHITESPACE=
typeset -g POWERLEVEL9K_{LEFT,RIGHT}_SUBSEGMENT_SEPARATOR=' '
typeset -g POWERLEVEL9K_ICON_PADDING=none
typeset -g POWERLEVEL9K_PROMPT_ADD_NEWLINE=true

# Directory
typeset -g POWERLEVEL9K_DIR_FOREGROUND="${_dots_p10k_colors[blue]}"
typeset -g POWERLEVEL9K_DIR_SHORTENED_FOREGROUND="${_dots_p10k_colors[blue]}"
typeset -g POWERLEVEL9K_DIR_ANCHOR_FOREGROUND="${_dots_p10k_colors[blue]}"

# Git (single color for every state, like the starship layout)
typeset -g POWERLEVEL9K_VCS_{CLEAN,MODIFIED,UNTRACKED,CONFLICTED,LOADING}_FOREGROUND="${_dots_p10k_colors[mauve]}"
typeset -g POWERLEVEL9K_VCS_BRANCH_ICON='-> '

# Prompt character
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="${_dots_p10k_colors[green]}"
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_FOREGROUND="${_dots_p10k_colors[red]}"
typeset -g POWERLEVEL9K_PROMPT_CHAR_OK_{VIINS,VICMD,VIVIS,VIOWR}_CONTENT_EXPANSION='❯'
typeset -g POWERLEVEL9K_PROMPT_CHAR_ERROR_{VIINS,VICMD,VIVIS,VIOWR}_CONTENT_EXPANSION='❯'

# Time
typeset -g POWERLEVEL9K_TIME_FOREGROUND="${_dots_p10k_colors[gray]}"
typeset -g POWERLEVEL9K_TIME_FORMAT='%D{%H:%M}'
typeset -g POWERLEVEL9K_TIME_UPDATE_ON_COMMAND=false

# No instant prompt: .zshrc has no instant-prompt preamble, and the plain
# startup is fast enough.
typeset -g POWERLEVEL9K_INSTANT_PROMPT=off

unset _dots_p10k_palette _dots_p10k_colors
