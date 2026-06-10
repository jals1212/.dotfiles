#!/bin/sh
# commands/prompt.sh — switch the active prompt engine (starship | p10k)
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_prompt_usage() {
    printf 'dots prompt — switch the active prompt engine\n\n'
    printf 'USAGE\n'
    printf '  ./dots prompt [--help|-h]\n'
    printf '  ./dots prompt --current\n'
    printf '  ./dots prompt <engine>\n\n'
    printf 'DESCRIPTION\n'
    printf '  Select the shell prompt engine. The choice is machine-local: it is\n'
    printf '  recorded as DOTS_PROMPT in ~/.config/zsh/local.zsh and in the\n'
    printf '  manifest — the repo itself never changes. Both engines follow the\n'
    printf '  active dots theme (p10k reads its palette from DOTS_THEME).\n\n'
    printf 'SUPPORTED ENGINES\n'
    printf '  starship : two starship invocations per prompt (left + right)\n'
    printf '  p10k     : powerlevel10k, async git via gitstatusd (lower latency)\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h    Print this message and exit 0.\n'
    printf '  --current     Print the active engine and exit.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots prompt p10k         # Switch to powerlevel10k\n'
    printf '  ./dots prompt starship     # Switch to starship\n'
    printf '  ./dots prompt --current    # Show active engine\n'
    printf '  ./dots prompt              # Interactive picker (TTY required)\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _prompt_usage
    exit 0
fi

# ---------------------------------------------------------------------------
# REPO_ROOT resolution
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source dependencies
# ---------------------------------------------------------------------------
# shellcheck source=src/lib/paths.sh
. "${REPO_ROOT}/src/lib/paths.sh"
# shellcheck source=src/lib/log.sh
. "$(path_src_lib log.sh)"
# shellcheck source=src/lib/tui.sh
. "$(path_src_lib tui.sh)"

if [ -f "$(path_src_lib header.sh)" ]; then
    # shellcheck source=src/lib/header.sh
    . "$(path_src_lib header.sh)"
fi

# shellcheck source=src/lib/theme.sh
. "$(path_src_lib theme.sh)"
# shellcheck source=src/lib/prompt.sh
. "$(path_src_lib prompt.sh)"
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"

# ---------------------------------------------------------------------------
# --current flag (early exit before banner)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--current" ]; then
    prompt_current
    exit $?
fi

# ---------------------------------------------------------------------------
# Banner: render only when not launched from the menu
# ---------------------------------------------------------------------------
tui_start_timer

if [ -z "${DOTS_FROM_MENU:-}" ]; then
    if command -v render_header >/dev/null 2>&1; then
        render_subcommand_banner "Prompt Switcher"
    else
        log_step "Prompt switcher"
    fi
fi

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
_pr_argc="${#}"
_pr_chosen=""

if [ "${_pr_argc}" -eq 0 ]; then
    # Interactive path: requires TTY
    if [ -t 0 ] && [ -t 1 ]; then
        _pr_chosen="$(select_prompt "$(prompt_current)")"
        prompt_apply "${_pr_chosen}"
    else
        _prompt_usage >&2
        exit 2
    fi
elif [ "${_pr_argc}" -eq 1 ]; then
    # Non-interactive: ./dots prompt <engine>
    _pr_chosen="${1}"
    prompt_apply "${_pr_chosen}"
else
    _prompt_usage >&2
    exit 2
fi

# ---------------------------------------------------------------------------
# Success banner
# ---------------------------------------------------------------------------
_pr_applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Prompt set" "${_pr_chosen}" "Open a new shell (or exec zsh) to use it" "Applied at ${_pr_applied_at}"
