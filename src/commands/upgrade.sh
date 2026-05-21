#!/bin/sh
# commands/upgrade.sh — bump vendored submodules + brew cleanup + mise prune
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots upgrade - vendored-deps lifecycle\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots upgrade [--commit] [--dry-run]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --commit      Stage and commit gitlink advances on success.\n' >&2
    printf '  --dry-run     Report changes without invoking destructive commands.\n' >&2
    printf '  --help, -h    Show this message.\n\n' >&2
    printf 'PHASES\n' >&2
    printf '  1. Bump pinned commit of dotbot/, plugins/dotbot-brew/,\n' >&2
    printf '     plugins/dotbot-mise/ to upstream default-branch HEAD.\n' >&2
    printf '  2. brew bundle cleanup --force --file=Brewfile.\n' >&2
    printf '  3. mise prune --yes.\n' >&2
    printf '  4. Print summary; optionally commit gitlinks.\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
_do_commit=0
_dry_run=0
for _arg in "$@"; do
    case "${_arg}" in
        --commit)  _do_commit=1 ;;
        --dry-run) _dry_run=1 ;;
        *)
            printf 'unknown flag: %s\n' "${_arg}" >&2
            printf 'run: ./dots upgrade --help\n' >&2
            exit 2
            ;;
    esac
done

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

render_subcommand_banner "Upgrade"

# ---------------------------------------------------------------------------
# Phase 1 — submodule pin bump
# ---------------------------------------------------------------------------
log_step "Phase 1: submodule pin bump"

_summary=""
_bumped=""

for _sub in dotbot plugins/dotbot-brew plugins/dotbot-mise; do
    _path="${REPO_ROOT}/${_sub}"
    if [ ! -d "${_path}" ]; then
        log_warn "${_sub}: not initialized; skipping"
        continue
    fi

    _old="$(cd "${_path}" && git rev-parse HEAD 2>/dev/null || printf 'unknown')"

    if [ "${_dry_run}" = 1 ]; then
        (cd "${_path}" && git fetch origin >/dev/null 2>&1 || true)
        _ahead="$(cd "${_path}" && git log "HEAD..origin/HEAD" --oneline 2>/dev/null | head -5 || true)"
        if [ -n "${_ahead}" ]; then
            log_info "${_sub}: upstream has new commits"
            printf '%s\n' "${_ahead}"
        else
            log_info "${_sub}: at upstream HEAD"
        fi
        continue
    fi

    git -C "${REPO_ROOT}" submodule update --remote --merge "${_sub}" >/dev/null 2>&1 || {
        log_warn "${_sub}: submodule update --remote failed; skipping"
        continue
    }
    _new="$(cd "${_path}" && git rev-parse HEAD 2>/dev/null || printf 'unknown')"

    if [ "${_old}" = "${_new}" ]; then
        log_info "${_sub}: at upstream HEAD (no change)"
    else
        _short_old="$(printf '%s' "${_old}" | cut -c1-7)"
        _short_new="$(printf '%s' "${_new}" | cut -c1-7)"
        log_ok "${_sub}: ${_short_old}..${_short_new}"
        _summary="${_summary}${_sub}: ${_short_old}..${_short_new}\n"
        _bumped="${_bumped}${_sub} "
    fi
done

# ---------------------------------------------------------------------------
# Phase 2 — brew bundle cleanup
# ---------------------------------------------------------------------------
log_step "Phase 2: brew bundle cleanup"

if command -v brew >/dev/null 2>&1; then
    if [ "${_dry_run}" = 1 ]; then
        brew bundle cleanup --file="${REPO_ROOT}/Brewfile" || true
    else
        brew bundle cleanup --force --file="${REPO_ROOT}/Brewfile" || true
    fi
else
    log_warn "brew not found; skipping bundle cleanup"
fi

# ---------------------------------------------------------------------------
# Phase 3 — mise prune
# ---------------------------------------------------------------------------
log_step "Phase 3: mise prune"

if command -v mise >/dev/null 2>&1; then
    if [ "${_dry_run}" = 1 ]; then
        log_info "dry-run: mise prune has no --dry-run; skipping"
    else
        mise prune --yes || true
    fi
else
    log_warn "mise not found; skipping prune"
fi

# ---------------------------------------------------------------------------
# Phase 4 — summary + optional commit
# ---------------------------------------------------------------------------
log_step "Phase 4: summary"

if [ -z "${_bumped}" ]; then
    log_info "all submodules current"
else
    printf '%b' "${_summary}"
fi

if [ "${_do_commit}" = 1 ] && [ -n "${_bumped}" ] && [ "${_dry_run}" = 0 ]; then
    git -C "${REPO_ROOT}" add .gitmodules dotbot plugins/dotbot-brew plugins/dotbot-mise
    _msg="$(printf 'chore(deps): upgrade %s\n\n%b' "${_bumped% }" "${_summary}")"
    git -C "${REPO_ROOT}" commit -m "${_msg}"
    log_ok "commit created"
elif [ "${_do_commit}" = 1 ] && [ -z "${_bumped}" ]; then
    log_info "--commit: no submodule advanced; no commit created"
fi

log_success "Upgrade complete" "${_bumped:-no submodules advanced}"
