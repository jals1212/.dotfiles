#!/bin/sh
# commands/clean.sh — remove dead symlinks + stale dotbot-backup files
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots clean - lifecycle maintenance\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots clean [--age=<days>] [--dry-run]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --age=<days>  Prune *.dotbot-backup.* older than N days (default: 30).\n' >&2
    printf '  --dry-run     Print what would be removed; do not modify anything.\n' >&2
    printf '  --help, -h    Show this message.\n\n' >&2
    printf 'DESCRIPTION\n' >&2
    printf '  Phase 1: remove broken symlinks in the managed directories (the\n' >&2
    printf '           parents of the Dotbot link destinations, including $HOME)\n' >&2
    printf '           whose target points inside this repository.\n' >&2
    printf '  Phase 2: prune <path>.dotbot-backup.<timestamp> files older than\n' >&2
    printf '           --age days (mtime check), only when <path> is a link\n' >&2
    printf '           destination declared by this repository.\n\n' >&2
    printf '  Only touches what this repo created: broken symlinks pointing\n' >&2
    printf '  elsewhere and backups of undeclared paths are left alone. Does NOT\n' >&2
    printf '  touch manifest.json or symlinks whose targets exist.\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
_age=30
_dry_run=0
for _arg in "$@"; do
    case "${_arg}" in
        --age=*)   _age="${_arg#--age=}" ;;
        --dry-run) _dry_run=1 ;;
        *)
            printf 'unknown flag: %s\n' "${_arg}" >&2
            printf 'run: ./dots clean --help\n' >&2
            exit 2
            ;;
    esac
done

case "${_age}" in
    ''|*[!0-9]*)
        printf 'invalid --age value: %s (expected non-negative integer)\n' "${_age}" >&2
        exit 2
        ;;
esac

# ---------------------------------------------------------------------------
# Compute REPO_ROOT
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT

# shellcheck source=src/lib/paths.sh
. "${REPO_ROOT}/src/lib/paths.sh"
# shellcheck source=src/lib/log.sh
. "$(path_src_lib log.sh)"
# shellcheck source=src/lib/tui.sh
. "$(path_src_lib tui.sh)"
# shellcheck source=src/lib/header.sh
. "$(path_src_lib header.sh)"
# shellcheck source=src/lib/dotbot.sh
. "$(path_src_lib dotbot.sh)"

render_subcommand_banner "Clean"

# ---------------------------------------------------------------------------
# Phase 1 — dead-symlink sweep via dotbot --only clean
# ---------------------------------------------------------------------------
log_step "Phase 1: dead-symlink sweep"

# Enumerate broken symlinks directly under managed directories, then keep only
# those whose target points into this repo (anything else, e.g. a dangling link
# in $HOME from another tool, was not created by us and is never touched). This
# count is used for the summary and (in --dry-run) for the would-remove listing.
_dead_tmpfile="$(mktemp)"
_dead_all="$(mktemp)"
_dirs_tmpfile="$(mktemp)"
_links_tmpfile="$(mktemp)"
_clean_cleanup() { rm -f "${_dead_tmpfile:-}" "${_dead_all:-}" "${_dirs_tmpfile:-}" "${_links_tmpfile:-}" "${_tmpfile:-}"; }
trap _clean_cleanup EXIT

# Resolve ownership inputs up front; abort (deleting nothing) if they fail.
dotbot_managed_dirs > "${_dirs_tmpfile}" || exit 1
dotbot_managed_links > "${_links_tmpfile}" || exit 1

while IFS= read -r _dir; do
    [ -d "${_dir}" ] || continue
    find "${_dir}" -maxdepth 1 -type l 2>/dev/null | while IFS= read -r _link; do
        [ -e "${_link}" ] || printf '%s\n' "${_link}"
    done
done < "${_dirs_tmpfile}" > "${_dead_all}"
dotbot_filter_repo_owned_links < "${_dead_all}" > "${_dead_tmpfile}" || exit 1

_dead_count=$(wc -l < "${_dead_tmpfile}" | tr -d ' ')

if [ "${_dry_run}" = 1 ]; then
    while IFS= read -r _link; do
        [ -n "${_link}" ] || continue
        printf 'would-remove: %s\n' "${_link}"
    done < "${_dead_tmpfile}"
else
    # Remove the broken symlinks ourselves (don't shell out to dotbot --only
    # clean: dotbot's stock clean plugin raises on some macOS Tahoe edge
    # cases when given `~` as a target. Our enumeration above already
    # restricts to known managed directories.)
    while IFS= read -r _link; do
        [ -n "${_link}" ] || continue
        rm -f "${_link}"
    done < "${_dead_tmpfile}"
fi

# ---------------------------------------------------------------------------
# Phase 2 — stale dotbot-backup prune
# ---------------------------------------------------------------------------
log_step "Phase 2: stale dotbot-backup prune (>${_age} days)"

_mtime_arg="+$((_age - 1))"
if [ "${_age}" = 0 ]; then
    _mtime_arg="+0"
fi

_stale_count=0
_tmpfile="$(mktemp)"
# _clean_cleanup (trap set in Phase 1) already covers ${_tmpfile}.

# A backup is ours only when it is <declared link destination>.dotbot-backup.
# <timestamp> (dotbot's naming; timestamp = digits and dashes).
: > "${_tmpfile}"
while IFS= read -r _dir; do
    [ -d "${_dir}" ] || continue
    find "${_dir}" -maxdepth 1 -type f -name '*.dotbot-backup.*' -mtime "${_mtime_arg}" 2>/dev/null
done < "${_dirs_tmpfile}" | while IFS= read -r _path; do
    _suffix="${_path##*.dotbot-backup.}"
    case "${_suffix}" in
        ''|*[!0-9-]*) continue ;;
    esac
    _origin="${_path%.dotbot-backup.*}"
    grep -Fxq -- "${_origin}" "${_links_tmpfile}" && printf '%s\n' "${_path}"
done > "${_tmpfile}" || true

if [ "${_dry_run}" = 1 ]; then
    while IFS= read -r _path; do
        [ -n "${_path}" ] || continue
        printf 'would-remove: %s\n' "${_path}"
        _stale_count=$((_stale_count + 1))
    done < "${_tmpfile}"
else
    while IFS= read -r _path; do
        [ -n "${_path}" ] || continue
        rm -f "${_path}"
        _stale_count=$((_stale_count + 1))
    done < "${_tmpfile}"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
if [ "${_dry_run}" = 1 ]; then
    log_success "Clean (dry-run)" "would remove ${_dead_count} dead symlink(s) + prune ${_stale_count} stale backup(s)"
else
    log_success "Clean complete" "removed ${_dead_count} dead symlink(s) + ${_stale_count} stale backup(s)"
fi
