#!/bin/sh
# commands/sync.sh — re-run base dotbot + reapply manifest theme
# POSIX sh. Invoked by the dots dispatcher or directly.
set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_sync_usage() {
    printf 'dots sync - re-run base dotbot + reapply manifest theme\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots sync\n\n' >&2
    printf 'BEHAVIOR\n' >&2
    printf '  Reads theme/flavor from manifest.json, runs ./install (base dotbot\n' >&2
    printf '  config, idempotent), then calls theme_apply with the recorded theme.\n' >&2
    printf '  Requires manifest.json to be present; run ./dots update first.\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --help / -h   Show this message.\n' >&2
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _sync_usage
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute REPO_ROOT and source libs
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT

# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/tui.sh
. "${REPO_ROOT}/lib/tui.sh"
# shellcheck source=lib/header.sh
. "${REPO_ROOT}/lib/header.sh"
# shellcheck source=lib/dotbot.sh
. "${REPO_ROOT}/lib/dotbot.sh"
# shellcheck source=lib/theme.sh
. "${REPO_ROOT}/lib/theme.sh"

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for sync)"

# ---------------------------------------------------------------------------
# Check manifest exists (theme_current also checks, but give clear error here)
# ---------------------------------------------------------------------------
if [ ! -f "${REPO_ROOT}/manifest.json" ]; then
    log_error "no manifest; run ./dots update first"
    exit 1
fi

# ---------------------------------------------------------------------------
# Read theme/flavor from manifest
# ---------------------------------------------------------------------------
_sync_pair="$(theme_current)" || exit 1
_sync_theme="$(printf '%s' "${_sync_pair}" | awk '{print $1}')"
_sync_flavor="$(printf '%s' "${_sync_pair}" | awk '{print $2}')"

# ---------------------------------------------------------------------------
# Base dotbot run
# ---------------------------------------------------------------------------
log_step "Running base dotbot config..."
dotbot_base_apply || {
    log_error "Base dotbot apply failed"
    exit 1
}

# ---------------------------------------------------------------------------
# Theme apply
# ---------------------------------------------------------------------------
log_step "Applying theme: ${_sync_theme}/${_sync_flavor}..."
theme_apply "${_sync_theme}" "${_sync_flavor}" || {
    log_error "Theme apply failed"
    exit 1
}

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
log_success "Sync complete" \
    "${_sync_theme}/${_sync_flavor}"
