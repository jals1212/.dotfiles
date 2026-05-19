#!/bin/sh
# commands/update.sh — re-deploy unconditionally using current selection
# POSIX sh. Invoked by the dots dispatcher or directly.
# Identical to apply except: no backup step, no hash gating.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots update - re-deploy dotfiles unconditionally\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots update\n\n' >&2
    printf 'Reads .dots-selection.json, deploys the payload, and refreshes manifest.json.\n' >&2
    printf "Does NOT create a backup. Use './dots apply' for a backup-before-deploy flow.\n" >&2
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
# shellcheck source=lib/detect.sh
. "${REPO_ROOT}/lib/detect.sh"
# shellcheck source=lib/select.sh
. "${REPO_ROOT}/lib/select.sh"
# shellcheck source=lib/deploy.sh
. "${REPO_ROOT}/lib/deploy.sh"
# shellcheck source=lib/manifest.sh
. "${REPO_ROOT}/lib/manifest.sh"

# ---------------------------------------------------------------------------
# Read and validate selection
# ---------------------------------------------------------------------------
_sel="${REPO_ROOT}/.dots-selection.json"
if [ ! -f "${_sel}" ]; then
    log_error ".dots-selection.json not found. Run: ./dots select"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not found on PATH. Run: brew install jq"
    exit 1
fi

_theme="$(jq -r '.theme  // empty' "${_sel}")"
_flavor="$(jq -r '.flavor // empty' "${_sel}")"
_accent="$(jq -r '.accent // empty' "${_sel}")"

if [ -z "${_theme}" ] || [ -z "${_flavor}" ]; then
    log_error "Selection file missing 'theme' or 'flavor'. Re-run: ./dots select"
    exit 1
fi

_accent="${_accent:-mauve}"
_tools_csv="$(jq -r '.tools | join(",")' "${_sel}")"

log_step "Validating selection: theme=${_theme} flavor=${_flavor}"
validate_theme  "${REPO_ROOT}" "${_theme}"
validate_flavor "${REPO_ROOT}" "${_theme}" "${_flavor}"
validate_accent "${REPO_ROOT}" "${_theme}" "${_accent}"
validate_tools  "${_tools_csv}"
log_info "Selection valid."

# ---------------------------------------------------------------------------
# Deploy (no backup — update is unconditional)
# ---------------------------------------------------------------------------
log_step "Deploying home payload..."
deploy_copy_home "${REPO_ROOT}"

log_step "Applying template substitution..."
deploy_apply_template "${REPO_ROOT}" "${_theme}" "${_flavor}" "${_accent}"

log_step "Materializing theme assets..."
deploy_theme_assets "${REPO_ROOT}" "${_theme}" "${_flavor}" "${_accent}"

log_step "Building bat cache..."
deploy_bat_cache

# Inject BAT_THEME block
_theme_tc="$(printf '%s' "${_theme}" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "${_theme}" | cut -c2-)"
_flavor_tc="$(printf '%s' "${_flavor}" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "${_flavor}" | cut -c2-)"
_bat_theme_name="${_theme_tc}-${_flavor_tc}"
_zshrc="${HOME}/.config/zsh/.zshrc"
if [ -f "${_zshrc}" ]; then
    log_step "Injecting BAT_THEME block into ${_zshrc}..."
    apply_block "${_zshrc}" "bat-theme" "export BAT_THEME=\"${_bat_theme_name}\""
fi

# ---------------------------------------------------------------------------
# Write manifest (refresh deployed_at)
# ---------------------------------------------------------------------------
log_step "Writing manifest..."
_hash="$(source_hash "${REPO_ROOT}")"
manifest_write "${REPO_ROOT}/manifest.json" \
    "${_theme}" "${_flavor}" "${_accent}" "${_tools_csv}" "${_hash}"

log_info "Update complete. Theme: ${_theme}/${_flavor}"
