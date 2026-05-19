#!/bin/sh
# commands/apply.sh — validate selection → backup → deploy → manifest
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots apply - deploy dotfiles from the current selection\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots apply\n\n' >&2
    printf 'Reads .dots-selection.json, creates a timestamped backup, copies the home\n' >&2
    printf 'payload, applies theme template substitution, materializes theme assets,\n' >&2
    printf 'builds the bat cache, and writes manifest.json.\n\n' >&2
    printf "Run './dots select' first to create a selection.\n" >&2
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
# shellcheck source=lib/backup.sh
. "${REPO_ROOT}/lib/backup.sh"
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
_tools_json="$(jq -r '.tools // empty' "${_sel}")"

if [ -z "${_theme}" ] || [ -z "${_flavor}" ]; then
    log_error "Selection file missing 'theme' or 'flavor'. Re-run: ./dots select"
    exit 1
fi

# Default accent if absent
_accent="${_accent:-mauve}"

# Convert tools JSON array → CSV for manifest_write / validate_tools
_tools_csv="$(jq -r '.tools | join(",")' "${_sel}")"

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
# Bat theme name: Titlecase-theme-Titlecase-flavor (mirrors deploy_theme_assets naming)
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
