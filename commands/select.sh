#!/bin/sh
# commands/select.sh — theme/tool selection wizard
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots select - run the interactive theme/tool selection wizard\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots select [--yes]\n\n' >&2
    printf 'BEHAVIOR\n' >&2
    printf '  Pre-populates from manifest.json (post-apply state) when present,\n' >&2
    printf '  otherwise from hardcoded defaults (kanagawa/dragon/mauve + all tools).\n' >&2
    printf '  Writes the transitory .dots-selection.json which apply consumes and removes.\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --yes    Non-interactive: write the pre-populated selection without prompting.\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute REPO_ROOT
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source libs
# ---------------------------------------------------------------------------
# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/header.sh
. "${REPO_ROOT}/lib/header.sh"
# shellcheck source=lib/select.sh
. "${REPO_ROOT}/lib/select.sh"

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
_yes=0
for _arg in "$@"; do
    case "${_arg}" in
        --yes|-y) _yes=1 ;;
    esac
done

# When YES=1 env var is set, treat as --yes
if [ "${YES:-0}" = "1" ]; then
    _yes=1
fi

# ---------------------------------------------------------------------------
# Pre-populate from manifest (post-apply state) or hardcoded defaults
# ---------------------------------------------------------------------------
_current="$(read_current_selection "${REPO_ROOT}")"
_cur_theme="$(printf '%s' "${_current}" | awk '{print $1}')"
_cur_flavor="$(printf '%s' "${_current}" | awk '{print $2}')"
_cur_accent="$(printf '%s' "${_current}" | awk '{print $3}')"
_cur_tools_csv="$(printf '%s' "${_current}" | awk '{print $4}')"

# ---------------------------------------------------------------------------
# Non-interactive / --yes path: write the pre-populated selection as-is
# ---------------------------------------------------------------------------
if [ "${_yes}" -eq 1 ] || ! [ -t 0 ]; then
    log_info "Non-interactive: writing selection (${_cur_theme}/${_cur_flavor}/${_cur_accent})"
    write_selection "${REPO_ROOT}/.dots-selection.json" \
        "${_cur_theme}" "${_cur_flavor}" "${_cur_accent}" "${_cur_tools_csv}"
    exit 0
fi

# ---------------------------------------------------------------------------
# Interactive path — pickers pre-focused on the current values
# ---------------------------------------------------------------------------
render_header "${_cur_theme}" "Selection Wizard"

log_step "Selecting theme..."
_theme="$(select_theme "${REPO_ROOT}" "${_cur_theme}")"

log_step "Selecting flavor..."
# Pre-focus current flavor only when the theme is unchanged.
_flavor_default=""
[ "${_theme}" = "${_cur_theme}" ] && _flavor_default="${_cur_flavor}"
_flavor="$(select_flavor "${REPO_ROOT}" "${_theme}" "${_flavor_default}")"

log_step "Selecting accent..."
_accent_default=""
[ "${_theme}" = "${_cur_theme}" ] && _accent_default="${_cur_accent}"
_accent="$(select_accent "${REPO_ROOT}" "${_theme}" "${_accent_default}")"

log_step "Selecting tools..."
_tools_nl="$(select_tools "${REPO_ROOT}" "${_cur_tools_csv}")"
# Convert newline-separated → comma-separated
_tools="$(printf '%s' "${_tools_nl}" | tr '\n' ',' | sed 's/,$//')"

# Confirm before writing
if confirm_apply; then
    write_selection "${REPO_ROOT}/.dots-selection.json" \
        "${_theme}" "${_flavor}" "${_accent}" "${_tools}"
    log_info "Selection saved. Run: ./dots apply"
else
    log_warn "Selection cancelled. No changes written."
    exit 1
fi
