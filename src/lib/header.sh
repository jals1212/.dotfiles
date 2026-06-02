#!/bin/sh
# lib/header.sh — braille skull header + theme color map
# POSIX sh. Source this file; call render_header [theme] [subtitle].
# Braille byte-identical to installer/internal/tui/header.go:5-19
# and home/.config/nvim/lua/plugins/snacks.lua dashboard header.

# ---------------------------------------------------------------------------
# Theme → ANSI 256-color foreground code map
# Add rows as new themes/flavors are added.
# ---------------------------------------------------------------------------
_header_color_code() {
    _theme="${1:-kanagawa}"
    case "${_theme}" in
        kanagawa|kanagawa/dragon|kanagawa/wave|kanagawa/lotus)
            printf '141' ;;   # oniViolet
        catppuccin|catppuccin/mocha)
            printf '183' ;;   # mauve mocha
        catppuccin/frappe)
            printf '140' ;;   # mauve frappe
        catppuccin/macchiato)
            printf '170' ;;   # mauve macchiato
        catppuccin/latte)
            printf '133' ;;   # mauve latte
        *)
            printf '141' ;;   # fallback: soft purple
    esac
}

# ---------------------------------------------------------------------------
# render_header [theme] [subtitle]
#   theme    — optional theme name/flavor (default: kanagawa)
#   subtitle — optional subtitle line   (default: Dotfiles Manager)
# Writes to stdout. Color applied only when stdout is a tty and tput
# reports >= 256 colors; otherwise plain UTF-8.
# ---------------------------------------------------------------------------
render_header() {
    _rh_theme="${1:-kanagawa}"
    _rh_subtitle="${2:-}"

    # Determine whether to use color
    _rh_use_color=0
    if [ -t 1 ]; then
        _rh_colors="$(tput colors 2>/dev/null || printf '8')"
        if [ "${_rh_colors}" -ge 256 ] 2>/dev/null; then
            _rh_use_color=1
        fi
    fi

    _rh_code="$(_header_color_code "${_rh_theme}")"

    # The 14-line braille skull (byte-identical to header.go const skullHeader)
    _rh_skull=$(cat <<'SKULL'
⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⣀⣠⣤⣤⣤⣤⣀⡀⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⣠⣤⢶⣻⣿⣻⣿⣿⣿⣿⣿⣿⣦⣤⣀⠄⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⣼⣺⢷⣻⣽⣾⣿⢿⣿⣷⣿⣿⢿⣿⣿⣿⣇⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠠⡍⢾⣺⢽⡳⣻⡺⣽⢝⢗⢯⣻⢽⣻⣿⣿⣿⣿⢿⡄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⡨⣖⢹⠜⢅⢫⢊⢎⠜⢌⠣⢑⠡⣹⡸⣜⣯⣿⢿⣻⣷⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⢜⢔⡹⡭⣪⢼⠽⠷⠧⣳⢘⢔⡝⠾⠽⢿⣷⣿⣟⢷⣟⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⢸⢘⢼⠿⠟⠁⠄⠄⡀⠄⠃⠑⡌⠄⠄⠈⠙⠿⣷⢽⣻⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⢌⠂⠅⠄⠄⠄⠄⠄⠄⡀⣲⣢⢂⠄⠄⠄⠄⠄⠈⣯⠏⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠐⠨⡂⠄⠄⠄⠄⠄⡀⡔⠋⢻⣤⡀⠄⠄⢀⠄⢸⣯⠇⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠈⣕⠝⠒⠄⠄⠒⢉⠪⠄⠄⠄⢿⠜⠑⠢⠠⡒⡺⣿⠖⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠐⠅⠁⡀⠄⠐⢔⠁⠄⠄⠄⢀⢇⢌⠄⠄⠄⠸⠕⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠂⠄⠄⠨⣔⡝⠼⡄⠂⣦⡆⣿⣲⠐⠑⠁⠄⠃⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠃⢫⢛⣙⡊⣜⣏⡝⣝⠆⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠈⠈⠁⠁⠁⠈⠈⠊⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄⠄
SKULL
)

    # JALS wordmark, prints between the skull and DOTS — personal brand.
    # Font: ANSI Shadow (figlet) — same font as the DOTS banner below.
    _rh_jals=$(cat <<'JALS'
⠄⠄⠄⠄⠄██╗⠄█████╗⠄██╗⠄⠄⠄⠄⠄███████╗
⠄⠄⠄⠄⠄██║██╔══██╗██║⠄⠄⠄⠄⠄██╔════╝
⠄⠄⠄⠄⠄██║███████║██║⠄⠄⠄⠄⠄███████╗
██⠄⠄⠄██║██╔══██║██║⠄⠄⠄⠄⠄╚════██║
╚█████╔╝██║⠄⠄██║███████╗███████║
⠄╚════╝⠄╚═╝⠄⠄╚═╝╚══════╝╚══════╝
JALS
)

    # DOTS block-letter banner, prints under the skull.
    # Font: ANSI Shadow (figlet) — box-drawing shadow effect.
    _rh_dots=$(cat <<'DOTS'
██████╗⠄⠄██████╗⠄████████╗███████╗
██╔══██╗██╔═══██╗╚══██╔══╝██╔════╝
██║⠄⠄██║██║⠄⠄⠄██║⠄⠄⠄██║⠄⠄⠄███████╗
██║⠄⠄██║██║⠄⠄⠄██║⠄⠄⠄██║⠄⠄⠄╚════██║
██████╔╝╚██████╔╝⠄⠄⠄██║⠄⠄⠄███████║
╚═════╝⠄⠄╚═════╝⠄⠄⠄⠄╚═╝⠄⠄⠄╚══════╝
DOTS
)

    # Center the skull and JALS (both 32 cols) over the 34-col DOTS banner with
    # a uniform 1-col indent. Applied at render time so the skull const stays
    # byte-identical to the nvim dashboard header in snacks.lua.
    _rh_skull=$(printf '%s\n' "${_rh_skull}" | sed 's/^/ /')
    _rh_jals=$(printf '%s\n' "${_rh_jals}" | sed 's/^/ /')

    if [ "${_rh_use_color}" -eq 1 ]; then
        # ANSI 256-color: ESC[38;5;<n>m ... ESC[0m
        printf '\033[38;5;%dm%s\033[0m\n' "${_rh_code}" "${_rh_skull}"
        printf '\033[38;5;%dm%s\033[0m\n' "${_rh_code}" "${_rh_jals}"
        printf '\033[38;5;%dm%s\033[0m\n' "${_rh_code}" "${_rh_dots}"
        if [ -n "${_rh_subtitle}" ]; then
            printf '\033[38;5;%dm%s\033[0m\n' "${_rh_code}" "${_rh_subtitle}"
        fi
    else
        printf '%s\n' "${_rh_skull}"
        printf '%s\n' "${_rh_jals}"
        printf '%s\n' "${_rh_dots}"
        if [ -n "${_rh_subtitle}" ]; then
            printf '%s\n' "${_rh_subtitle}"
        fi
    fi
}
