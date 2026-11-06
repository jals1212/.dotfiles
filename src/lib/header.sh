#!/bin/sh
# lib/header.sh — theme color map
# POSIX sh. Source this file; call _header_color_code [theme].
# The one-line subcommand header lives in lib/tui.sh (render_command_banner).

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
