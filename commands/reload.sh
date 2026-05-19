#!/bin/sh
# commands/reload.sh — re-deploy only when source hash has drifted (or --force)
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots reload - re-deploy when source hash differs from manifest\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots reload [--force]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --force   Re-deploy even when hashes match.\n\n' >&2
    printf 'Compares current source hash against manifest.json. If they match\n' >&2
    printf 'and --force is not set, prints "already current" and exits 0.\n' >&2
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
# Parse flags
# ---------------------------------------------------------------------------
_force=0
for _arg in "$@"; do
    case "${_arg}" in
        --force) _force=1 ;;
    esac
done

# ---------------------------------------------------------------------------
# Check manifest exists
# ---------------------------------------------------------------------------
_manifest="${REPO_ROOT}/manifest.json"
if [ ! -f "${_manifest}" ]; then
    log_error "manifest.json not found. Run: ./dots apply first."
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    log_error "jq is required but not found on PATH. Run: brew install jq"
    exit 1
fi

# ---------------------------------------------------------------------------
# Compare hashes
# ---------------------------------------------------------------------------
_manifest_hash="$(manifest_read_field "${_manifest}" "source_hash")"
_current_hash="$(source_hash "${REPO_ROOT}")"

if [ "${_current_hash}" = "${_manifest_hash}" ] && [ "${_force}" -eq 0 ]; then
    log_info "already current (hash=${_current_hash})"
    exit 0
fi

if [ "${_force}" -eq 1 ]; then
    log_step "Force flag set — redeploying unconditionally."
else
    log_step "Source hash differs — redeploying."
    log_info "  manifest: ${_manifest_hash}"
    log_info "  current:  ${_current_hash}"
fi

# ---------------------------------------------------------------------------
# Read selection
# ---------------------------------------------------------------------------
_sel="${REPO_ROOT}/.dots-selection.json"
if [ ! -f "${_sel}" ]; then
    log_error ".dots-selection.json not found. Run: ./dots select"
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

validate_theme  "${REPO_ROOT}" "${_theme}"
validate_flavor "${REPO_ROOT}" "${_theme}" "${_flavor}"
validate_accent "${REPO_ROOT}" "${_theme}" "${_accent}"
validate_tools  "${_tools_csv}"

# ---------------------------------------------------------------------------
# Deploy (no backup for reload — same as update semantics)
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
_zshrc="${HOME}/.zshrc"
if [ -f "${_zshrc}" ]; then
    log_step "Injecting BAT_THEME block into ${_zshrc}..."
    apply_block "${_zshrc}" "bat-theme" "export BAT_THEME=\"${_bat_theme_name}\""
fi

# ---------------------------------------------------------------------------
# Update manifest with new hash
# ---------------------------------------------------------------------------
log_step "Writing manifest..."
_new_hash="$(source_hash "${REPO_ROOT}")"
manifest_write "${REPO_ROOT}/manifest.json" \
    "${_theme}" "${_flavor}" "${_accent}" "${_tools_csv}" "${_new_hash}"

log_info "Reload complete. Theme: ${_theme}/${_flavor}"
