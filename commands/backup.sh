#!/bin/sh
# commands/backup.sh — create an explicit backup of managed dotfiles
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots backup - create a backup of managed dotfiles\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots backup\n\n' >&2
    printf 'BEHAVIOR\n' >&2
    printf '  Copies existing managed files from HOME into .backups/TIMESTAMP/.\n' >&2
    printf '  Does not deploy, sync, restore, or modify manifest.json.\n' >&2
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
# shellcheck source=lib/backup.sh
. "${REPO_ROOT}/lib/backup.sh"

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for backup)"

log_step "Creating backup of existing managed configs..."
_backup_dir="$(backup_create "${REPO_ROOT}")"

if [ -n "${_backup_dir}" ]; then
    log_success "Backup complete" "path=${_backup_dir}"
else
    log_success "Backup complete" "nothing to back up"
fi
