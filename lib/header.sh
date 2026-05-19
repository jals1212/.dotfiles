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
        dracula|dracula/*)
            printf '141' ;;   # purple
        tokyonight|tokyonight/*)
            printf '111' ;;   # blue
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
    _rh_subtitle="${2:-Dotfiles Manager}"

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
⠄⠄⠄⠄⠄⠄⠄⠄⠄⣀⣠⣤⣤⣤⣤⣀⡀⠄⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⣠⣤⢶⣻⣿⣻⣿⣿⣿⣿⣿⣿⣦⣤⣀⠄⠄⠄⠄⠄
⠄⠄⠄⠄⣼⣺⢷⣻⣽⣾⣿⢿⣿⣷⣿⣿⢿⣿⣿⣿⣇⠄⠄⠄⠄
⠄⠄⠠⡍⢾⣺⢽⡳⣻⡺⣽⢝⢗⢯⣻⢽⣻⣿⣿⣿⣿⢿⡄⠄⠄
⠄⠄⡨⣖⢹⠜⢅⢫⢊⢎⠜⢌⠣⢑⠡⣹⡸⣜⣯⣿⢿⣻⣷⠄⠄
⠄⠄⢜⢔⡹⡭⣪⢼⠽⠷⠧⣳⢘⢔⡝⠾⠽⢿⣷⣿⣟⢷⣟⠄⠄
⠄⠄⢸⢘⢼⠿⠟⠁⠄⠄⡀⠄⠃⠑⡌⠄⠄⠈⠙⠿⣷⢽⣻⠄⠄
⠄⠄⢌⠂⠅⠄⠄⠄⠄⠄⠄⡀⣲⣢⢂⠄⠄⠄⠄⠄⠈⣯⠏⠄⠄
⠄⠄⠐⠨⡂⠄⠄⠄⠄⠄⡀⡔⠋⢻⣤⡀⠄⠄⢀⠄⢸⣯⠇⠄⠄
⠄⠄⠈⣕⠝⠒⠄⠄⠒⢉⠪⠄⠄⠄⢿⠜⠑⠢⠠⡒⡺⣿⠖⠄⠄
⠄⠄⠄⠐⠅⠁⡀⠄⠐⢔⠁⠄⠄⠄⢀⢇⢌⠄⠄⠄⠸⠕⠄⠄⠄
⠄⠄⠄⠄⠂⠄⠄⠨⣔⡝⠼⡄⠂⣦⡆⣿⣲⠐⠑⠁⠄⠃⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⠃⢫⢛⣙⡊⣜⣏⡝⣝⠆⠄⠄⠄⠄⠄⠄⠄
⠄⠄⠄⠄⠄⠄⠄⠄⠈⠈⠁⠁⠁⠈⠈⠊⠄⠄⠄⠄⠄⠄⠄⠄⠄
SKULL
)

    if [ "${_rh_use_color}" -eq 1 ]; then
        # ANSI 256-color: ESC[38;5;<n>m ... ESC[0m
        printf '\033[38;5;%dm%s\033[0m\n' "${_rh_code}" "${_rh_skull}"
        printf '\033[38;5;%dm%s\033[0m\n' "${_rh_code}" "${_rh_subtitle}"
    else
        printf '%s\n' "${_rh_skull}"
        printf '%s\n' "${_rh_subtitle}"
    fi
}
