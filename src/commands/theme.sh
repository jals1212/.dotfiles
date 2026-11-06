#!/bin/sh
# commands/theme.sh — switch the active dots theme
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_theme_usage() {
    printf 'dots theme — switch the active dots theme\n\n'
    printf 'USAGE\n'
    printf '  ./dots theme [--help|-h]\n'
    printf '  ./dots theme --current\n'
    printf '  ./dots theme <theme> <flavor>\n\n'
    printf 'DESCRIPTION\n'
    printf '  Apply a theme/flavor pair by running the per-theme dotbot config,\n'
    printf '  rewriting the Starship and Herdr fenced lines, rebuilding the bat cache, optionally\n'
    printf '  reloading running tmux/Herdr servers, and writing the slim manifest.\n\n'
    printf 'SUPPORTED THEMES AND FLAVORS\n'
    printf '  kanagawa   : dragon, lotus, wave\n'
    printf '  catppuccin : frappe, latte, macchiato, mocha\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h    Print this message and exit 0.\n'
    printf '  --current     Print the active <theme> <flavor> pair and exit.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots theme kanagawa dragon     # Apply kanagawa/dragon\n'
    printf '  ./dots theme catppuccin mocha    # Apply catppuccin/mocha\n'
    printf '  ./dots theme --current           # Show active theme\n'
    printf '  ./dots theme                     # Interactive picker (TTY required)\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _theme_usage
    exit 0
fi

# ---------------------------------------------------------------------------
# REPO_ROOT resolution
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source dependencies
# ---------------------------------------------------------------------------
# shellcheck source=src/lib/paths.sh
. "${REPO_ROOT}/src/lib/paths.sh"
# shellcheck source=src/lib/log.sh
. "$(path_src_lib log.sh)"
# shellcheck source=src/lib/tui.sh
. "$(path_src_lib tui.sh)"

if [ -f "$(path_src_lib header.sh)" ]; then
    # shellcheck source=src/lib/header.sh
    . "$(path_src_lib header.sh)"
fi

# shellcheck source=src/lib/dotbot.sh
. "$(path_src_lib dotbot.sh)"
# shellcheck source=src/lib/theme.sh
. "$(path_src_lib theme.sh)"
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"

# ---------------------------------------------------------------------------
# --current flag (early exit before banner)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--current" ]; then
    theme_current
    exit $?
fi

# ---------------------------------------------------------------------------
# Banner (render_subcommand_banner is a no-op under DOTS_MENU_DISPATCH)
# ---------------------------------------------------------------------------
tui_start_timer
render_subcommand_banner "Theme"

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
_th_argc="${#}"
_th_chosen_theme=""
_th_chosen_flavor=""

if [ "${_th_argc}" -eq 0 ]; then
    # Interactive path: requires TTY
    if [ -t 0 ] && [ -t 1 ]; then
        _th_cur_theme=""
        _th_cur_flavor=""
        if theme_current >/dev/null 2>&1; then
            _th_pair="$(theme_current 2>/dev/null)" || true
            _th_cur_theme="${_th_pair%% *}"
            _th_cur_flavor="${_th_pair##* }"
        fi

        _th_chosen_theme="$(select_theme "${REPO_ROOT}" "${_th_cur_theme:-}")"
        _th_chosen_flavor="$(select_flavor "${REPO_ROOT}" "${_th_chosen_theme}" "${_th_cur_flavor:-}")"

        theme_apply "${_th_chosen_theme}" "${_th_chosen_flavor}"
    else
        _theme_usage >&2
        exit 2
    fi
elif [ "${_th_argc}" -eq 2 ]; then
    # Non-interactive: ./dots theme <theme> <flavor>
    _th_chosen_theme="${1}"
    _th_chosen_flavor="${2}"
    theme_apply "${_th_chosen_theme}" "${_th_chosen_flavor}"
else
    _theme_usage >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Success banner
# ---------------------------------------------------------------------------
_th_applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Theme set" "${_th_chosen_theme}/${_th_chosen_flavor}" "Applied at ${_th_applied_at}"
