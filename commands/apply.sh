#!/bin/sh
# commands/apply.sh — non-interactive deploy replay
# POSIX sh. Invoked by the dots dispatcher or directly.
#
# Reads theme/flavor/accent/tools from manifest.json (or hardcoded defaults
# from lib/select.sh when no manifest exists), then runs the full deploy
# pipeline (backup → deploy → manifest). No wizard, no prompts.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots apply - non-interactive replay of the deploy pipeline\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots apply\n\n' >&2
    printf 'BEHAVIOR\n' >&2
    printf '  Reads theme/flavor/accent/tools from manifest.json (or hardcoded\n' >&2
    printf '  defaults if absent), creates a timestamped backup, deploys the\n' >&2
    printf '  payload, materializes theme assets, builds the bat cache, and\n' >&2
    printf '  refreshes manifest.json.\n\n' >&2
    printf '  This is the non-interactive sibling of ./dots select.\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute REPO_ROOT and source libs
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT

# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/detect.sh
. "${REPO_ROOT}/lib/detect.sh"
# shellcheck source=lib/select.sh
. "${REPO_ROOT}/lib/select.sh"
# shellcheck source=lib/backup.sh
. "${REPO_ROOT}/lib/backup.sh"
# shellcheck source=lib/deploy.sh
. "${REPO_ROOT}/lib/deploy.sh"
# shellcheck source=lib/manifest.sh
. "${REPO_ROOT}/lib/manifest.sh"

# ---------------------------------------------------------------------------
# Source of truth: manifest.json (or hardcoded defaults via read_current_selection)
# ---------------------------------------------------------------------------
_current="$(read_current_selection "${REPO_ROOT}")"
_theme="$(printf '%s' "${_current}" | awk '{print $1}')"
_flavor="$(printf '%s' "${_current}" | awk '{print $2}')"
_accent="$(printf '%s' "${_current}" | awk '{print $3}')"
_tools_csv="$(printf '%s' "${_current}" | awk '{print $4}')"

log_info "Apply input: ${_theme}/${_flavor}/${_accent} + tools=${_tools_csv}"

# ---------------------------------------------------------------------------
# Validate
# ---------------------------------------------------------------------------
log_step "Validating selection: theme=${_theme} flavor=${_flavor} accent=${_accent}"
validate_theme  "${REPO_ROOT}" "${_theme}"
validate_flavor "${REPO_ROOT}" "${_theme}" "${_flavor}"
validate_accent "${REPO_ROOT}" "${_theme}" "${_accent}"
validate_tools  "${_tools_csv}"
log_info "Selection valid."

# ---------------------------------------------------------------------------
# Backup existing configs
# ---------------------------------------------------------------------------
log_step "Creating backup of existing managed configs..."
backup_create "${REPO_ROOT}"

# ---------------------------------------------------------------------------
# Deploy
# ---------------------------------------------------------------------------
log_step "Deploying home payload..."
deploy_copy_home "${REPO_ROOT}"

log_step "Applying template substitution..."
deploy_apply_template "${REPO_ROOT}" "${_theme}" "${_flavor}" "${_accent}"

log_step "Materializing theme assets..."
deploy_theme_assets "${REPO_ROOT}" "${_theme}" "${_flavor}" "${_accent}"

log_step "Building bat cache..."
deploy_bat_cache

# Inject BAT_THEME block into deployed .zshrc
_theme_tc="$(printf '%s' "${_theme}" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "${_theme}" | cut -c2-)"
_flavor_tc="$(printf '%s' "${_flavor}" | cut -c1 | tr '[:lower:]' '[:upper:]')$(printf '%s' "${_flavor}" | cut -c2-)"
_bat_theme_name="${_theme_tc}-${_flavor_tc}"
_zshrc="${HOME}/.zshrc"
if [ -f "${_zshrc}" ]; then
    log_step "Injecting BAT_THEME block into ${_zshrc}..."
    apply_block "${_zshrc}" "bat-theme" "export BAT_THEME=\"${_bat_theme_name}\""
fi

# ---------------------------------------------------------------------------
# Write manifest
# ---------------------------------------------------------------------------
log_step "Writing manifest..."
_hash="$(source_hash "${REPO_ROOT}")"
manifest_write "${REPO_ROOT}/manifest.json" \
    "${_theme}" "${_flavor}" "${_accent}" "${_tools_csv}" "${_hash}"

log_info "Apply complete. Theme: ${_theme}/${_flavor}"
