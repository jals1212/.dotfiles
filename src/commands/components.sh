#!/bin/sh
# commands/components.sh — choose which terminal components ./dots installs
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_components_usage() {
    printf 'dots components — choose which terminal components get installed\n\n'
    printf 'USAGE\n'
    printf '  ./dots components [--help|-h]\n'
    printf '  ./dots components --current\n'
    printf '  ./dots components <id>... | none\n\n'
    printf 'DESCRIPTION\n'
    printf '  Check the components you want in a checklist (space toggles, enter\n'
    printf '  confirms, q cancels). Nothing is checked until you check it. The\n'
    printf '  choice is machine-local: it is recorded as DOTS_COMPONENTS in\n'
    printf '  ~/.config/zsh/local.zsh (a space-separated list of ids, or none) —\n'
    printf '  the repo itself never changes. ./dots update asks the same checklist\n'
    printf '  once, on a TTY, while no selection is recorded.\n\n'
    printf 'COMPONENTS\n'
    printf '  tmux        : tmux + gitmux\n'
    printf '  herdr-tui   : Herdr terminal UI (brew formula "herdr")\n'
    printf '  herdr-core  : Herdr core (official installer)\n'
    printf '  herdr-app   : Herdr desktop app; brings the core, so checking it\n'
    printf '                also checks herdr-core\n'
    printf '  ghostty     : Ghostty terminal (macOS cask)\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h    Print this message and exit 0.\n'
    printf '  --current     Print the recorded selection (none when empty or\n'
    printf '                never recorded) and exit.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots components tmux herdr-app   # Select tmux, the Herdr app and its core\n'
    printf '  ./dots components none             # Select nothing\n'
    printf '  ./dots components --current        # Show the selection\n'
    printf '  ./dots components                  # Interactive checklist (TTY required)\n\n'
    printf 'An unknown id exits 1 and changes nothing.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _components_usage
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
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"

# ---------------------------------------------------------------------------
# --current flag (early exit before banner)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--current" ]; then
    components_current
    exit $?
fi

tui_start_timer
render_subcommand_banner "Components"

# ---------------------------------------------------------------------------
# Argument parsing: nothing is recorded before every argument is valid.
# ---------------------------------------------------------------------------
if [ "$#" -eq 0 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        _co_chosen="$(select_components "$(components_selected | tr '\n' ' ')")"
    else
        _components_usage >&2
        exit 2
    fi
elif [ "$1" = "${COMPONENT_NONE}" ]; then
    if [ "$#" -gt 1 ]; then
        log_error "'${COMPONENT_NONE}' cannot be combined with component ids"
        exit 1
    fi
    _co_chosen=""
else
    for _co_id in "$@"; do
        components_validate "${_co_id}" || exit 1
    done
    _co_chosen="$(components_normalize "$@")"
fi

# shellcheck disable=SC2086
components_apply ${_co_chosen} || exit 1

# ---------------------------------------------------------------------------
# Success banner
# ---------------------------------------------------------------------------
_co_applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Components set" "${_co_chosen:-${COMPONENT_NONE}}" "Recorded as DOTS_COMPONENTS in ~/.config/zsh/local.zsh" "Applied at ${_co_applied_at}"
