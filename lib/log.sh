#!/bin/sh
# lib/log.sh — structured logging helpers
# POSIX sh. Source this file; do not execute directly.
# All output goes to stderr. Color applied only when stderr is a tty
# and NO_COLOR is unset/empty.

# ---------------------------------------------------------------------------
# Internal: emit a colored (or plain) log line to stderr.
#   _log_line <color_code> <prefix> <message>
# ---------------------------------------------------------------------------
_log_line() {
    _ll_code="${1}"
    _ll_prefix="${2}"
    _ll_msg="${3}"

    # Color when: stderr is a tty AND NO_COLOR is unset or empty
    if [ -t 2 ] && [ -z "${NO_COLOR:-}" ]; then
        printf '\033[38;5;%dm%s\033[0m %s\n' "${_ll_code}" "${_ll_prefix}" "${_ll_msg}" >&2
    else
        printf '%s %s\n' "${_ll_prefix}" "${_ll_msg}" >&2
    fi
}

# log_info <message>  — informational message (blue-ish, ANSI 111)
log_info() {
    _log_line 111 '[INFO]' "${*}"
}

# log_warn <message>  — warning (yellow, ANSI 214)
log_warn() {
    _log_line 214 '[WARN]' "${*}"
}

# log_error <message> — error (red, ANSI 196)
log_error() {
    _log_line 196 '[ERROR]' "${*}"
}

# log_step <message>  — section header / major step (purple, ANSI 141)
log_step() {
    _log_line 141 '[STEP]' "${*}"
}

# log_ok <message>    — positive checkpoint (green, ANSI 76)
log_ok() {
    _log_line 76 '[OK]' "${*}"
}
