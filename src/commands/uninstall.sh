#!/bin/sh
# commands/uninstall.sh — remove dotbot-managed symlinks + manifest
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots uninstall - remove dotbot-managed symlinks\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots uninstall [--yes]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --yes        Skip confirmation prompt.\n' >&2
    printf '  --help, -h   Show this message.\n\n' >&2
    printf 'DESCRIPTION\n' >&2
    # shellcheck disable=SC2016
    printf '  Removes every symlink under $HOME whose target resolves into\n' >&2
    # shellcheck disable=SC2016
    printf '  $DOTFILES, then removes manifest.json. Does NOT touch\n' >&2
    printf '  <path>.dotbot-backup.<timestamp> siblings (recover originals\n' >&2
    printf '  by inspecting them manually).\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
_yes=0
for _arg in "$@"; do
    case "${_arg}" in
        --yes) _yes=1 ;;
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
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT

# shellcheck source=src/lib/log.sh
. "${REPO_ROOT}/src/lib/log.sh"
# shellcheck source=src/lib/tui.sh
. "${REPO_ROOT}/src/lib/tui.sh"
# shellcheck source=src/lib/header.sh
. "${REPO_ROOT}/src/lib/header.sh"

render_subcommand_banner "Uninstall"

# ---------------------------------------------------------------------------
# Confirmation
# ---------------------------------------------------------------------------
if [ "${_yes}" != 1 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        if command -v gum >/dev/null 2>&1; then
            if ! gum confirm "Remove every dotbot-managed symlink and manifest.json?"; then
                log_info "uninstall aborted"
                exit 0
            fi
        else
            printf 'Remove every dotbot-managed symlink and manifest.json? [y/N] '
            read -r _ans
            case "${_ans}" in
                y|Y|yes|YES) ;;
                *) log_info "uninstall aborted"; exit 0 ;;
            esac
        fi
    else
        log_error "uninstall on non-TTY requires --yes"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Remove dotbot-managed symlinks
# ---------------------------------------------------------------------------
log_step "Removing dotbot-managed symlinks under \$HOME"

_removed=0
_tmpfile="$(mktemp)"
trap 'rm -f "${_tmpfile}"' EXIT

# Enumerate every symlink under $HOME.
find "${HOME}" -type l 2>/dev/null > "${_tmpfile}" || true

while IFS= read -r _link; do
    [ -n "${_link}" ] || continue
    _target="$(readlink -f "${_link}" 2>/dev/null || true)"
    case "${_target}" in
        "${REPO_ROOT}"/*)
            rm -f "${_link}"
            _removed=$((_removed + 1))
            ;;
    esac
done < "${_tmpfile}"

log_ok "removed ${_removed} symlink(s)"

# ---------------------------------------------------------------------------
# Remove manifest
# ---------------------------------------------------------------------------
_manifest="${REPO_ROOT}/manifest.json"
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
