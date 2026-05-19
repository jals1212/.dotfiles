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
    printf 'FLAGS\n' >&2
    printf '  --yes    Non-interactive: use existing .dots-selection.json or defaults.\n' >&2
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
# Non-interactive / --yes path
# ---------------------------------------------------------------------------
if [ "${_yes}" -eq 1 ] || ! [ -t 0 ]; then
    _sel="${REPO_ROOT}/.dots-selection.json"
    if [ -f "${_sel}" ]; then
        log_info "Non-interactive mode: using existing selection from ${_sel}"
        exit 0
    else
        # Write defaults
        log_info "Non-interactive mode: writing default selection (kanagawa/dragon/mauve + all tools)"
        write_selection "${_sel}" "kanagawa" "dragon" "mauve" \
            "zsh,tmux,nvim,ghostty,oh-my-posh,atuin,zoxide"
        exit 0
    fi
fi

# ---------------------------------------------------------------------------
# Interactive path
# ---------------------------------------------------------------------------
# Render header (use existing selection theme if available)
_existing_theme="kanagawa"
_existing_sel="${REPO_ROOT}/.dots-selection.json"
if command -v jq >/dev/null 2>&1 && [ -f "${_existing_sel}" ]; then
    _existing_theme="$(jq -r '.theme // "kanagawa"' "${_existing_sel}")"
fi
render_header "${_existing_theme}" "Selection Wizard"

log_step "Selecting theme..."
_theme="$(select_theme "${REPO_ROOT}")"

log_step "Selecting flavor..."
_flavor="$(select_flavor "${REPO_ROOT}" "${_theme}")"

log_step "Selecting accent..."
_accent="$(select_accent "${REPO_ROOT}" "${_theme}")"

log_step "Selecting tools..."
_tools_nl="$(select_tools "${REPO_ROOT}")"
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
