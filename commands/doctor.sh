#!/bin/sh
# commands/doctor.sh — run health checks via lib/doctor.sh
# POSIX sh. Invoked by the dots dispatcher or directly.
# NOTE: lib/doctor.sh is implemented in Sec 6. Until then this command exits 1
# with a clear message (forward-ref approach — no stub functions here).

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    printf 'dots doctor - run environment health checks\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots doctor\n\n' >&2
    printf 'Invokes check_* functions from lib/doctor.sh.\n' >&2
    printf 'Prints X/Y checks passed and exits 0 if all pass, 1 otherwise.\n\n' >&2
    printf 'Requires lib/doctor.sh (implemented in Section 6 of the migration).\n' >&2
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
# Defensively source lib/doctor.sh (Sec 6 pending)
# ---------------------------------------------------------------------------
_doctor_lib="${REPO_ROOT}/lib/doctor.sh"
if [ ! -f "${_doctor_lib}" ]; then
    log_error "lib/doctor.sh missing (Sec 6 pending)"
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
