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
    printf '  Commands present   : python3, brew, zsh, tmux, nvim, git, jq, gum\n'
    printf '  Submodules         : dotbot, plugins/dotbot-brew, plugins/dotbot-mise\n'
    printf '  Required symlinks  : .zshrc, .zprofile, .zshenv, nvim, tmux, ghostty,\n'
    printf '                       atuin, mise (all resolve into the repo)\n'
    printf '  Theme symlinks     : oh-my-posh, bat, fzf, eza, lazygit, bottom,\n'
    printf '                       ghostty/themes/dots, atuin/themes/dots.toml\n'
    printf '  Nvim theme         : manifest-driven Lua helper is readable\n'
    printf '  Theme agreement    : all theme symlinks resolve to the same\n'
    printf '                       <theme>/<flavor>\n'
    printf '  Content markers    : tmux prefix C-a, ghostty theme = dots,\n'
    printf '                       BAT_THEME="dots" literal in .zshrc,\n'
    printf '                       atuin [theme] name = "dots"\n'
    printf '  Tmux fence         : exactly one open + close fence with @ukiyo-theme\n'
    printf '  Slim manifest      : keys = {version, theme, flavor, applied_at};\n'
    printf '                       theme/flavor whitelisted; no legacy keys\n'
    printf '  JSON validity      : oh-my-posh config.json via symlink target\n'
    printf '  Maintenance (WARN) : *.dotbot-backup.* older than 30 days\n\n'
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
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source base libs
# ---------------------------------------------------------------------------
# shellcheck source=src/lib/paths.sh
. "${REPO_ROOT}/src/lib/paths.sh"
# shellcheck source=src/lib/log.sh
. "$(path_src_lib log.sh)"
# shellcheck source=src/lib/detect.sh
. "$(path_src_lib detect.sh)"
# shellcheck source=src/lib/tui.sh
. "$(path_src_lib tui.sh)"

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for doctor)"

# ---------------------------------------------------------------------------
# Source lib/doctor.sh (defines check_* functions and DOCTOR_CHECKS registry)
# ---------------------------------------------------------------------------
_doctor_lib="$(path_src_lib doctor.sh)"
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

if [ "${_fail}" -gt 0 ]; then
    exit 1
fi

log_success "Doctor complete" "${_pass}/${_total} checks passed"
exit 0
