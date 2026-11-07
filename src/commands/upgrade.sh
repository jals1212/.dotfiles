#!/bin/sh
# commands/upgrade.sh — bump vendored submodules + report optional cleanup/prune
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots upgrade - vendored-deps lifecycle (safe by default)\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots upgrade [--commit] [--dry-run] [--cleanup] [--prune] [--yes]\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --commit      Commit only the gitlinks it advanced; other staged files stay staged.\n' >&2
    printf '  --dry-run     Report submodule changes only; with --cleanup, report cleanup candidates.\n' >&2
    printf '  --cleanup     Opt into Homebrew cleanup phase (report with --dry-run, apply with --yes).\n' >&2
    printf '  --prune       Allow mise prune to remove unused tool installs.\n' >&2
    printf '  --yes         Required with --cleanup/--prune to skip confirmation.\n' >&2
    printf '  --help, -h    Show this message.\n\n' >&2
    printf 'SAFETY\n' >&2
    printf '  Default mode NEVER runs brew cleanup --force and NEVER runs mise prune.\n' >&2
    printf '  Cleanup/prune are destructive and require explicit flags plus confirmation.\n\n' >&2
    printf 'PHASES\n' >&2
    printf '  1. Bump pinned commit of vendor/dotbot/, vendor/plugins/dotbot-brew/,\n' >&2
    printf '     vendor/plugins/dotbot-mise/ to upstream default-branch HEAD.\n' >&2
    printf '  2. Skip Homebrew cleanup unless --cleanup is explicit.\n' >&2
    printf '  3. Skip mise prune unless --prune is explicit.\n' >&2
    printf '  4. Print summary; optionally commit the advanced gitlinks only.\n' >&2
    exit 0
fi

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
_do_commit=0
_dry_run=0
_do_cleanup=0
_do_prune=0
_yes=0
for _arg in "$@"; do
    case "${_arg}" in
        --commit)   _do_commit=1 ;;
        --dry-run)  _dry_run=1 ;;
        --cleanup)  _do_cleanup=1 ;;
        --prune)    _do_prune=1 ;;
        --yes|-y)   _yes=1 ;;
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

render_subcommand_banner "Upgrade"

_upgrade_confirm_destructive() {
    _ucd_what="${1:?_upgrade_confirm_destructive: description required}"

    if [ "${_dry_run}" = 1 ]; then
        return 1
    fi

    if [ "${_yes}" = 1 ]; then
        return 0
    fi

    if [ -t 0 ] && [ -t 1 ]; then
        # Only an explicit y proceeds; enter defaults to No.
        tui_confirm "Destructive action: ${_ucd_what}. Continue?" n
        return $?
    fi

    log_error "${_ucd_what} is destructive; rerun with --yes to confirm"
    return 1
}

# ---------------------------------------------------------------------------
# Phase 1 — submodule pin bump
# ---------------------------------------------------------------------------
log_step "Phase 1: submodule pin bump"

_summary=""
_bumped=""

for _sub in vendor/dotbot vendor/plugins/dotbot-brew vendor/plugins/dotbot-mise; do
    case "${_sub}" in
        vendor/dotbot) _path="$(path_vendor_dotbot)" ;;
        vendor/plugins/dotbot-brew) _path="$(path_vendor_dotbot_brew)" ;;
        vendor/plugins/dotbot-mise) _path="$(path_vendor_dotbot_mise)" ;;
    esac
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
# Phase 2 — optional brew bundle cleanup report / apply
# ---------------------------------------------------------------------------
log_step "Phase 2: brew bundle cleanup"

if [ "${_do_cleanup}" != 1 ]; then
    log_info "safe mode: skipping brew cleanup (use --cleanup --dry-run to inspect; --cleanup --yes to apply)"
elif ! command -v brew >/dev/null 2>&1; then
    log_warn "brew not found; skipping bundle cleanup"
elif [ "${_dry_run}" = 1 ]; then
    log_info "dry-run: reporting cleanup candidates only (nothing removed)"
    brew bundle cleanup --file="$(path_brewfile)" || true
elif _upgrade_confirm_destructive "brew bundle cleanup --force may uninstall apps, casks, formulae, and taps not listed in config/Brewfile"; then
    log_warn "Running destructive Homebrew cleanup (--force)"
    brew bundle cleanup --force --file="$(path_brewfile)" || true
else
    log_warn "brew cleanup skipped"
fi

# ---------------------------------------------------------------------------
# Phase 3 — mise prune report / optional apply
# ---------------------------------------------------------------------------
log_step "Phase 3: mise prune"

if command -v mise >/dev/null 2>&1; then
    if [ "${_do_prune}" = 1 ] && _upgrade_confirm_destructive "mise prune may remove unused tool installs"; then
        log_warn "Running destructive mise prune"
        mise prune --yes || true
    else
        log_info "safe mode: skipping mise prune (use --prune --yes to apply)"
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
    # Commit only the gitlinks advanced in Phase 1: `add` stages them, `commit
    # --only` then leaves whatever else is staged out of the commit. _bumped is a
    # space-separated list of vendored submodule paths (never containing
    # spaces), so it is deliberately left unquoted to split into arguments.
    # shellcheck disable=SC2086
    git -C "${REPO_ROOT}" add -- ${_bumped}
    _msg="$(printf 'chore(deps): upgrade %s\n\n%b' "${_bumped% }" "${_summary}")"
    # shellcheck disable=SC2086
    git -C "${REPO_ROOT}" commit --only -m "${_msg}" -- ${_bumped}
    log_ok "commit created"
elif [ "${_do_commit}" = 1 ] && [ -z "${_bumped}" ]; then
    log_info "--commit: no submodule advanced; no commit created"
fi

log_success "Upgrade complete" "${_bumped:-no submodules advanced}" "cleanup=${_do_cleanup} prune=${_do_prune}"
