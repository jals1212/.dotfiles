#!/bin/sh
# commands/select.sh — interactive theme/tool selection + full deploy
# POSIX sh. Invoked by the dots dispatcher or directly.
#
# The wizard runs in-process: pickers feed shell variables which then drive
# the deploy pipeline (backup → deploy → manifest). There is no transitory
# selection file.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots select - interactive selection wizard + full deploy\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots select [--yes]\n\n' >&2
    printf 'BEHAVIOR\n' >&2
    printf '  Runs the gum-backed wizard (pre-populated from manifest.json if\n' >&2
    printf '  present, otherwise from hardcoded defaults), then executes the\n' >&2
    printf '  full deploy pipeline (backup → deploy → manifest).\n\n' >&2
    printf '  No transitory file is written between wizard and deploy.\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --yes    Non-interactive: skip pickers, use pre-populated values,\n' >&2
    printf '           and run the deploy pipeline immediately.\n' >&2
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
# shellcheck source=lib/header.sh
. "${REPO_ROOT}/lib/header.sh"
# shellcheck source=lib/select.sh
. "${REPO_ROOT}/lib/select.sh"
# shellcheck source=lib/backup.sh
. "${REPO_ROOT}/lib/backup.sh"
# shellcheck source=lib/deploy.sh
. "${REPO_ROOT}/lib/deploy.sh"
# shellcheck source=lib/manifest.sh
. "${REPO_ROOT}/lib/manifest.sh"

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
_yes=0
for _arg in "$@"; do
    case "${_arg}" in
        --yes|-y) _yes=1 ;;
    esac
done
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
# Determine final theme/flavor/accent/tools — wizard or pre-populated
# ---------------------------------------------------------------------------
if [ "${_yes}" -eq 1 ] || ! [ -t 0 ]; then
    _theme="${_cur_theme}"
    _flavor="${_cur_flavor}"
    _accent="${_cur_accent}"
    _tools_csv="${_cur_tools_csv}"
    log_info "Non-interactive: ${_theme}/${_flavor}/${_accent} + tools=${_tools_csv}"
else
    render_header "${_cur_theme}" "Selection Wizard"

    log_step "Selecting theme..."
    _theme="$(select_theme "${REPO_ROOT}" "${_cur_theme}")"

    log_step "Selecting flavor..."
    _flavor_default=""
    [ "${_theme}" = "${_cur_theme}" ] && _flavor_default="${_cur_flavor}"
    _flavor="$(select_flavor "${REPO_ROOT}" "${_theme}" "${_flavor_default}")"

    log_step "Selecting accent..."
    _accent_default=""
    [ "${_theme}" = "${_cur_theme}" ] && _accent_default="${_cur_accent}"
    _accent="$(select_accent "${REPO_ROOT}" "${_theme}" "${_accent_default}")"

    log_step "Selecting tools..."
    _tools_nl="$(select_tools "${REPO_ROOT}" "${_cur_tools_csv}")"
    _tools_csv="$(printf '%s' "${_tools_nl}" | tr '\n' ',' | sed 's/,$//')"

    if ! confirm_apply; then
        log_warn "Selection cancelled. No backup or deploy performed."
        exit 1
    fi
fi

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

# Inject BAT_THEME block into deployed .zshrc.
# Bat theme is materialized as dots.tmTheme by deploy_theme_assets; the env var
# stays stable across flavor switches.
_zshrc="${HOME}/.zshrc"
if [ -f "${_zshrc}" ]; then
    log_step "Injecting BAT_THEME block into ${_zshrc}..."
    apply_block "${_zshrc}" "bat-theme" 'export BAT_THEME="dots"'
fi

# ---------------------------------------------------------------------------
# Write manifest
# ---------------------------------------------------------------------------
log_step "Writing manifest..."
_hash="$(source_hash "${REPO_ROOT}")"
manifest_write "${REPO_ROOT}/manifest.json" \
    "${_theme}" "${_flavor}" "${_accent}" "${_tools_csv}" "${_hash}"

log_info "Select complete. Theme: ${_theme}/${_flavor}"
