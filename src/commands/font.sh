#!/bin/sh
# commands/font.sh — switch the terminal font (jetbrains-mono | iosevka)
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_font_usage() {
    printf 'dots font — switch the terminal font\n\n'
    printf 'USAGE\n'
    printf '  ./dots font [--help|-h]\n'
    printf '  ./dots font --current\n'
    printf '  ./dots font <font>\n\n'
    printf 'DESCRIPTION\n'
    printf '  Select the Nerd Font Ghostty uses. The choice is machine-local: it is\n'
    printf '  recorded as DOTS_FONT in ~/.config/zsh/local.zsh and rendered into\n'
    printf '  ~/.config/ghostty/font.conf — the repo itself never changes. On macOS\n'
    printf '  the font'"'"'s Homebrew cask is installed when missing. When the herdr-app\n'
    printf '  component is selected (./dots components) the font family is also set as\n'
    printf '  "font" in ~/.config/herdr-app/settings.json (under XDG_CONFIG_HOME when\n'
    printf '  set; other keys are kept; needs jq or python3; an invalid file is left\n'
    printf '  untouched with a warning). Herdr app reloads that file live.\n\n'
    printf 'SUPPORTED FONTS\n'
    printf '  jetbrains-mono : JetBrainsMono Nerd Font (default)\n'
    printf '  iosevka        : IosevkaTerm NF\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h    Print this message and exit 0.\n'
    printf '  --current     Print the active font and exit.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots font iosevka          # Switch to Iosevka\n'
    printf '  ./dots font jetbrains-mono   # Switch to JetBrains Mono\n'
    printf '  ./dots font --current        # Show active font\n'
    printf '  ./dots font                  # Interactive picker (TTY required)\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _font_usage
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
# shellcheck source=src/lib/detect.sh
. "$(path_src_lib detect.sh)"
# shellcheck source=src/lib/tui.sh
. "$(path_src_lib tui.sh)"
# shellcheck source=src/lib/header.sh
. "$(path_src_lib header.sh)"
# shellcheck source=src/lib/theme.sh
. "$(path_src_lib theme.sh)"
# shellcheck source=src/lib/components.sh
. "$(path_src_lib components.sh)"
# shellcheck source=src/lib/font.sh
. "$(path_src_lib font.sh)"
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"

# ---------------------------------------------------------------------------
# --current flag (early exit before banner)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--current" ]; then
    font_current
    exit $?
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ "$#" -gt 1 ]; then
    _font_usage >&2
    exit 2
fi

tui_start_timer
render_subcommand_banner "Font"

if [ "$#" -eq 0 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        _fo_chosen="$(select_font "$(font_current)")"
    else
        _font_usage >&2
        exit 2
    fi
else
    _fo_chosen="${1}"
fi

font_apply "${_fo_chosen}" || exit 1

# ---------------------------------------------------------------------------
# Success banner
# ---------------------------------------------------------------------------
_fo_applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Font set" "${_fo_chosen}" "Reload Ghostty config (cmd+shift+,) or open a new window" "Applied at ${_fo_applied_at}"
