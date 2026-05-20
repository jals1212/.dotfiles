#!/bin/sh
# commands/restore.sh — restore a backup to $HOME
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    # shellcheck disable=SC2016
    printf 'dots restore - restore a backup to $HOME\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots restore\n' >&2
    printf '  ./dots restore --latest\n' >&2
    printf '  ./dots restore PATH\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  no args    Interactive backup picker (newest first).\n' >&2
    printf '  --latest   Restore the most recent backup under .backups/.\n' >&2
    printf '  PATH       Explicit path to a backup directory.\n\n' >&2
    printf 'Backups live under .backups/TIMESTAMP/ at the repository root.\n' >&2
    # shellcheck disable=SC2016
    printf 'Copies backup contents to $HOME. Does NOT remove manifest.json.\n' >&2
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
# shellcheck source=lib/tui.sh
. "${REPO_ROOT}/lib/tui.sh"
# shellcheck source=lib/backup.sh
. "${REPO_ROOT}/lib/backup.sh"

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for restore)"

# ---------------------------------------------------------------------------
# Parse args
# ---------------------------------------------------------------------------
_backup_dir=""
_use_latest=0
_interactive_pick=0

if [ $# -eq 0 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        _interactive_pick=1
    else
        log_error "restore requires --latest or an explicit backup path in non-interactive mode."
        log_error "Run: ./dots restore --help"
        exit 1
    fi
fi

for _arg in "$@"; do
    case "${_arg}" in
        --latest) _use_latest=1 ;;
        --*)
            log_error "Unknown flag: ${_arg}"
            exit 1
            ;;
        *)
            _backup_dir="${_arg}"
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Resolve backup directory
# ---------------------------------------------------------------------------
if [ "${_interactive_pick}" -eq 1 ]; then
    if ! command -v gum >/dev/null 2>&1; then
        log_error "gum is required for interactive restore. Use: ./dots restore --latest"
        exit 1
    fi
    _backup_list="$(backup_list "${REPO_ROOT}")"
    if [ -z "${_backup_list}" ]; then
        log_error "No backups found under ${REPO_ROOT}/.backups/"
        exit 1
    fi
    _backup_dir="$(printf '%s\n' "${_backup_list}" | gum choose --header "Choose backup to restore (newest first)")"
    if [ -z "${_backup_dir}" ]; then
        log_warn "Restore cancelled. No files changed."
        exit 1
    fi
elif [ "${_use_latest}" -eq 1 ]; then
    _backup_dir="$(backup_latest "${REPO_ROOT}")"
    if [ -z "${_backup_dir}" ]; then
        log_error "No backups found under ${REPO_ROOT}/.backups/"
        exit 1
    fi
    log_info "Latest backup: ${_backup_dir}"
else
    if [ -z "${_backup_dir}" ]; then
        log_error "restore requires --latest or an explicit backup path."
        exit 1
    fi
    if [ ! -d "${_backup_dir}" ]; then
        log_error "Backup directory not found: ${_backup_dir}"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Restore
# ---------------------------------------------------------------------------
restore_from "${REPO_ROOT}" "${_backup_dir}"
log_success "Restore complete" "source=${_backup_dir}"
