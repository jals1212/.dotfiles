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
    printf '  Phase 1: dotbot --only clean removes broken symlinks under the\n' >&2
    printf '           managed directories declared in install.conf.yaml clean:.\n' >&2
    printf '  Phase 2: prune <path>.dotbot-backup.<timestamp> siblings older than\n' >&2
    printf '           --age days (mtime check).\n\n' >&2
    printf '  Does NOT touch manifest.json, theme symlinks (whose targets exist),\n' >&2
    printf '  the tmux fenced block, or the atuin static [theme] name.\n' >&2
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
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT

# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/tui.sh
. "${REPO_ROOT}/lib/tui.sh"
# shellcheck source=lib/header.sh
. "${REPO_ROOT}/lib/header.sh"
# shellcheck source=lib/dotbot.sh
. "${REPO_ROOT}/lib/dotbot.sh"

render_subcommand_banner "Clean"

# ---------------------------------------------------------------------------
# Phase 1 — dead-symlink sweep via dotbot --only clean
# ---------------------------------------------------------------------------
log_step "Phase 1: dead-symlink sweep"

_dead_count=0

if [ "${_dry_run}" = 1 ]; then
    log_info "dry-run: enumerating broken symlinks under managed dirs"
    for _dir in \
        "${HOME}" \
        "${HOME}/.config/zsh" \
        "${HOME}/.config/nvim" \
        "${HOME}/.config/tmux" \
        "${HOME}/.config/ghostty" \
        "${HOME}/.config/atuin" \
        "${HOME}/.config/atuin/themes" \
        "${HOME}/.config/aerospace" \
        "${HOME}/.config/mise" \
        "${HOME}/.config/dots" \
        "${HOME}/.config/oh-my-posh" \
        "${HOME}/.config/bat/themes" \
        "${HOME}/.config/eza/themes" \
        "${HOME}/.config/fzf/themes" \
        "${HOME}/.config/lazygit" \
        "${HOME}/.config/bottom"
    do
        [ -d "${_dir}" ] || continue
        find "${_dir}" -maxdepth 1 -type l 2>/dev/null | while IFS= read -r _link; do
            if [ ! -e "${_link}" ]; then
                printf 'would-remove: %s\n' "${_link}"
            fi
        done
    done
else
    dotbot_check_submodules || exit 1
    python3 "${REPO_ROOT}/dotbot/bin/dotbot" \
        --plugin "${REPO_ROOT}/plugins/dotbot-brew/brew.py" \
        --plugin "${REPO_ROOT}/plugins/dotbot-mise/mise.py" \
        -d "${REPO_ROOT}" \
        -c "${REPO_ROOT}/install.conf.yaml" \
        --only clean
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
trap 'rm -f "${_tmpfile}"' EXIT

find "${HOME}" -type f -name '*.dotbot-backup.*' -mtime "${_mtime_arg}" 2>/dev/null > "${_tmpfile}" || true

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
    log_success "Clean (dry-run)" "would prune ${_stale_count} stale backup(s); see output above for broken symlink candidates"
else
    log_success "Clean complete" "removed ${_dead_count} dead symlink(s) + ${_stale_count} stale backup(s)"
fi
