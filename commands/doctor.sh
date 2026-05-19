#!/bin/sh
# commands/doctor.sh — run health checks via lib/doctor.sh
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots doctor — run environment health checks\n\n'
    printf 'USAGE\n'
    printf '  ./dots doctor [--help|-h]\n\n'
    printf 'DESCRIPTION\n'
    printf '  Non-mutating health check over the local environment and deployed dotfiles.\n'
    printf '  Runs all check_* functions registered in lib/doctor.sh and prints a\n'
    printf '  PASS/FAIL/WARN/SKIP line for each. Exits 0 when all checks pass, 1 otherwise.\n\n'
    printf 'CHECK CATEGORIES\n'
    printf '  Commands present   : brew, zsh, tmux, nvim, git, jq, gum\n'
    printf '  Files present      : manifest.json (post-apply)\n'
    printf '  JSON validity      : manifest.json\n'
    printf '  Hash drift         : computed source_hash vs manifest stored hash\n'
    printf '  Content markers    : tmux prefix C-a, ghostty theme = dots,\n'
    printf '                       BAT_THEME="dots" block in .zshrc\n'
    printf '  Theme dst files    : bat/themes/dots.tmTheme, fzf/themes/dots.sh,\n'
    printf '                       eza/themes/dots.sh\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h   Print this message and exit 0 without running checks.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots doctor          # Run all checks\n'
    printf '  ./dots doctor --help   # Print usage\n'
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute REPO_ROOT
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source base libs
# ---------------------------------------------------------------------------
# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/detect.sh
. "${REPO_ROOT}/lib/detect.sh"

# ---------------------------------------------------------------------------
# Source lib/doctor.sh (defines check_* functions and DOCTOR_CHECKS registry)
# ---------------------------------------------------------------------------
_doctor_lib="${REPO_ROOT}/lib/doctor.sh"
if [ ! -f "${_doctor_lib}" ]; then
    log_error "lib/doctor.sh missing"
    exit 1
fi
# shellcheck disable=SC1090,SC1091
. "${_doctor_lib}"

# ---------------------------------------------------------------------------
# Discover and run all check_* functions
# ---------------------------------------------------------------------------
# lib/doctor.sh must define check_* functions.
# We enumerate them via a known list exported by that library.
# doctor.sh is expected to export DOCTOR_CHECKS as a space-separated list.

_pass=0
_fail=0

if [ -z "${DOCTOR_CHECKS:-}" ]; then
    log_error "lib/doctor.sh did not export DOCTOR_CHECKS. Check its implementation."
    exit 1
fi

for _check_fn in ${DOCTOR_CHECKS}; do
    if "${_check_fn}"; then
        _pass=$((_pass + 1))
    else
        _fail=$((_fail + 1))
    fi
done

_total=$((_pass + _fail))
log_info "Doctor: ${_pass}/${_total} checks passed."

if [ "${_fail}" -gt 0 ]; then
    exit 1
fi

exit 0
