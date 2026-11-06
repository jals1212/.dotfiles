#!/bin/sh
# commands/uninstall.sh — remove declared dotbot-managed symlinks + manifest
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots uninstall - remove declared dotbot-managed symlinks\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots uninstall [--yes] [--dry-run]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --yes        Skip confirmation prompt.\n' >&2
    printf '  --dry-run    Print what would be removed; do not modify anything.\n' >&2
    printf '  --help, -h   Show this message.\n\n' >&2
    printf 'DESCRIPTION\n' >&2
    printf '  Removes only symlink destinations declared by the current Dotbot\n' >&2
    printf '  configs when their targets resolve into this repo, then removes\n' >&2
    printf '  manifest.json. Does NOT scan all of $HOME and does NOT touch\n' >&2
    printf '  <path>.dotbot-backup.<timestamp> siblings (recover originals\n' >&2
    printf '  by inspecting them manually).\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
_yes=0
_dry_run=0
for _arg in "$@"; do
    case "${_arg}" in
        --yes) _yes=1 ;;
        --dry-run) _dry_run=1 ;;
        *)
            printf 'unknown flag: %s\n' "${_arg}" >&2
            printf 'run: ./dots uninstall --help\n' >&2
            exit 2
            ;;
    esac
done

# ---------------------------------------------------------------------------
# Compute REPO_ROOT
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd -P)"
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

render_subcommand_banner "Uninstall"

# ---------------------------------------------------------------------------
# Build removal allowlist
# ---------------------------------------------------------------------------
log_step "Inspecting declared Dotbot symlink destinations"

_links_tmpfile="$(mktemp)"
_remove_tmpfile="$(mktemp)"
_cleanup() { rm -f "${_links_tmpfile:-}" "${_remove_tmpfile:-}"; }
trap _cleanup EXIT

dotbot_managed_links > "${_links_tmpfile}"
: > "${_remove_tmpfile}"

while IFS= read -r _link; do
    [ -n "${_link}" ] || continue
    [ -L "${_link}" ] || continue

    _target="$(readlink -f "${_link}" 2>/dev/null || true)"
    case "${_target}" in
        "${REPO_ROOT}"/*) printf '%s -> %s\n' "${_link}" "${_target}" >> "${_remove_tmpfile}" ;;
    esac
done < "${_links_tmpfile}"

_remove_count="$(wc -l < "${_remove_tmpfile}" | tr -d ' ')"

if [ "${_remove_count}" -gt 0 ]; then
    log_info "Declared symlink(s) selected for removal:"
    while IFS= read -r _entry; do
        [ -n "${_entry}" ] || continue
        printf '  %s\n' "${_entry}" >&2
    done < "${_remove_tmpfile}"
else
    log_info "no declared symlinks to remove"
fi

if [ "${_dry_run}" = 1 ]; then
    if [ -f "$(path_manifest)" ]; then
        printf 'would-remove: %s\n' "$(path_manifest)" >&2
    fi
    log_success "Uninstall (dry-run)" "would remove ${_remove_count} symlink(s)"
    exit 0
fi

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------
if [ "${_yes}" != 1 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        # Only an explicit y removes anything; n, enter, q, esc and end of
        # input all abort.
        if ! tui_confirm "Remove the declared dotbot-managed symlinks listed above and manifest.json?" n; then
            log_info "uninstall aborted"
            exit 0
        fi
    else
        log_error "uninstall on non-TTY requires --yes"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Remove declared dotbot-managed symlinks
# ---------------------------------------------------------------------------
log_step "Removing declared dotbot-managed symlinks"

_removed=0
while IFS= read -r _entry; do
    [ -n "${_entry}" ] || continue
    _link="${_entry%% -> *}"
    [ -L "${_link}" ] || continue
    _target="$(readlink -f "${_link}" 2>/dev/null || true)"
    case "${_target}" in
        "${REPO_ROOT}"/*)
            rm -f "${_link}"
            _removed=$((_removed + 1))
            ;;
    esac
done < "${_remove_tmpfile}"

log_ok "removed ${_removed} symlink(s)"

# ---------------------------------------------------------------------------
# Remove manifest
# ---------------------------------------------------------------------------
_manifest="$(path_manifest)"
if [ -f "${_manifest}" ]; then
    rm -f "${_manifest}"
    log_ok "removed manifest.json"
else
    log_info "no manifest.json to remove"
fi

# ---------------------------------------------------------------------------
# Reminder
# ---------------------------------------------------------------------------
log_info "dotbot-backup siblings preserved at <path>.dotbot-backup.<timestamp>"

log_success "Uninstall complete" "${_removed} symlink(s) removed"
