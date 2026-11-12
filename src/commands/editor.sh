#!/bin/sh
# commands/editor.sh — choose the terminal $EDITOR (nvim | fresh)
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_editor_usage() {
    printf 'dots editor — choose the terminal $EDITOR\n\n'
    printf 'USAGE\n'
    printf '  ./dots editor [--help|-h]\n'
    printf '  ./dots editor --current\n'
    printf '  ./dots editor <editor>\n\n'
    printf 'DESCRIPTION\n'
    printf '  Select the editor the terminal opens ($EDITOR and $VISUAL). The choice is\n'
    printf '  machine-local: it is recorded as DOTS_EDITOR in ~/.config/zsh/local.zsh\n'
    printf '  and exported by ~/.config/zsh/.zshenv (default nvim) — the repo itself\n'
    printf '  never changes. It does not install anything: pick the editors you want\n'
    printf '  with ./dots components (a warning is printed when the chosen editor is\n'
    printf '  not selected there).\n\n'
    printf 'SUPPORTED EDITORS\n'
    printf '  nvim   : Neovim (default)\n'
    printf '  fresh  : Fresh editor (Homebrew fresh-editor, command fresh)\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h    Print this message and exit 0.\n'
    printf '  --current     Print the active editor and exit.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots editor fresh     # Use Fresh as $EDITOR\n'
    printf '  ./dots editor nvim      # Use Neovim as $EDITOR\n'
    printf '  ./dots editor --current # Show active editor\n'
    printf '  ./dots editor           # Interactive picker (TTY required)\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _editor_usage
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
# shellcheck source=src/lib/editor.sh
. "$(path_src_lib editor.sh)"
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"

# ---------------------------------------------------------------------------
# --current flag (early exit before banner)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--current" ]; then
    editor_current
    exit $?
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
if [ "$#" -gt 1 ]; then
    _editor_usage >&2
    exit 2
fi

tui_start_timer
render_subcommand_banner "Editor"

if [ "$#" -eq 0 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        _ed_chosen="$(select_editor "$(editor_current)")"
    else
        _editor_usage >&2
        exit 2
    fi
else
    _ed_chosen="${1}"
fi

editor_apply "${_ed_chosen}" || exit 1

# ---------------------------------------------------------------------------
# Success banner
# ---------------------------------------------------------------------------
_ed_applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Editor set" "${_ed_chosen}" "Open a new shell to use it" "Applied at ${_ed_applied_at}"
