#!/bin/sh
# commands/components.sh — choose which terminal components ./dots installs
# POSIX sh. Invoked by the dots dispatcher or directly.

set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_components_usage() {
    printf 'dots components — choose which terminal components get installed\n\n'
    printf 'USAGE\n'
    printf '  ./dots components [--help|-h]\n'
    printf '  ./dots components --current\n'
    printf '  ./dots components [--yes] [<id>... | none]\n\n'
    printf 'DESCRIPTION\n'
    printf '  Check the components you want in a checklist (space toggles, enter\n'
    printf '  confirms, q cancels). Nothing is checked until you check it. The\n'
    printf '  choice is machine-local: it is recorded as DOTS_COMPONENTS in\n'
    printf '  ~/.config/zsh/local.zsh (a space-separated list of ids, or none) —\n'
    printf '  the repo itself never changes. ./dots update asks the same checklist\n'
    printf '  once, on a TTY, while no selection is recorded.\n\n'
    printf '  UNCHECKING UNINSTALLS. A component that was recorded as selected and\n'
    printf '  is now unchecked is uninstalled (brew uninstall, or the official\n'
    printf '  install files on Linux) and its repo symlinks removed, after a\n'
    printf '  confirmation that lists exactly what goes (default No). Components\n'
    printf '  never recorded are never uninstalled, so the first selection removes\n'
    printf '  nothing. See REMOVAL below.\n\n'
    printf 'COMPONENTS\n'
    printf '  tmux        : tmux + gitmux\n'
    printf '  herdr-tui   : Herdr terminal UI (brew formula "herdr")\n'
    printf '  herdr-core  : Herdr core (official installer)\n'
    printf '  herdr-app   : Herdr desktop app; brings the core, so checking it\n'
    printf '                also checks herdr-core\n'
    printf '  ghostty     : Ghostty terminal (macOS cask)\n\n'
    printf 'OPTIONS\n'
    printf '  --help, -h    Print this message and exit 0.\n'
    printf '  --current     Print the recorded selection (none when empty or\n'
    printf '                never recorded) and exit.\n'
    printf '  --yes         Skip the removal confirmation. Without it and without a\n'
    printf '                TTY, a change that removes something exits 2 and\n'
    printf '                changes nothing.\n\n'
    printf 'REMOVAL (only for components recorded before and unchecked now)\n'
    printf '  tmux        : brew uninstall tmux gitmux (the installed ones); the\n'
    printf '                ~/.config/tmux symlinks into this repo\n'
    printf '  herdr-tui   : brew uninstall herdr\n'
    printf '  herdr-app   : macOS: brew uninstall --cask herdr-app, plus an official\n'
    printf '                install (~/Applications/Herdr.app and the\n'
    printf '                ~/.local/bin/herdr-app link into it). Linux: the\n'
    printf '                official install (${XDG_DATA_HOME:-~/.local/share}/herdr-app,\n'
    printf '                ~/.local/bin/herdr-app, its .desktop and icon files)\n'
    printf '  herdr-core  : ~/.local/bin/herdr-core and ~/.local/bin/hc when they\n'
    printf '                are regular files or symlinks (else a warning); never\n'
    printf '                while herdr-app stays selected\n'
    printf '  herdr config: ~/.config/herdr/config.toml link, only when no Herdr\n'
    printf '                component remains\n'
    printf '  ghostty     : macOS: brew uninstall --cask ghostty; the\n'
    printf '                ~/.config/ghostty config, shaders and themes/dots\n'
    printf '                links into this repo (font.conf and other files stay)\n'
    printf '  Only symlinks that point into this repo are removed. A missing\n'
    printf '  package is skipped; a failing uninstall warns, the rest continues,\n'
    printf '  the exit code is non-zero and the new selection is still recorded.\n'
    printf '  Declining or cancelling the confirmation changes nothing.\n\n'
    printf 'EXAMPLES\n'
    printf '  ./dots components tmux herdr-app   # Select tmux, the Herdr app and its core\n'
    printf '  ./dots components none             # Select nothing (asks before uninstalling)\n'
    printf '  ./dots components --yes none       # Same, without asking\n'
    printf '  ./dots components --current        # Show the selection\n'
    printf '  ./dots components                  # Interactive checklist (TTY required)\n\n'
    printf 'An unknown id exits 1 and changes nothing.\n'
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _components_usage
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
# shellcheck source=src/lib/detect.sh
. "$(path_src_lib detect.sh)"
# shellcheck source=src/lib/tui.sh
. "$(path_src_lib tui.sh)"
# shellcheck source=src/lib/header.sh
. "$(path_src_lib header.sh)"
# shellcheck source=src/lib/theme.sh
. "$(path_src_lib theme.sh)"
# shellcheck source=src/lib/components.sh
. "$(path_src_lib components.sh)"
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"
# shellcheck source=src/lib/dotbot.sh
. "$(path_src_lib dotbot.sh)"

# ---------------------------------------------------------------------------
# --current flag (early exit before banner)
# ---------------------------------------------------------------------------
if [ "${1:-}" = "--current" ]; then
    components_current
    exit $?
fi

tui_start_timer
render_subcommand_banner "Components"

# ---------------------------------------------------------------------------
# Argument parsing: nothing is recorded before every argument is valid.
# --yes may appear anywhere; everything else is a component id or `none`.
# ---------------------------------------------------------------------------
_co_yes=0
_co_n=$#
while [ "${_co_n}" -gt 0 ]; do
    _co_arg="$1"
    shift
    _co_n=$((_co_n - 1))
    if [ "${_co_arg}" = "--yes" ]; then
        _co_yes=1
    else
        set -- "$@" "${_co_arg}"
    fi
done

# The recorded selection before this change (empty when never recorded).
_co_old="$(components_selected | tr '\n' ' ')"

if [ "$#" -eq 0 ]; then
    if [ -t 0 ] && [ -t 1 ]; then
        _co_chosen="$(select_components "${_co_old}")" || exit $?
    else
        _components_usage >&2
        exit 2
    fi
elif [ "$1" = "${COMPONENT_NONE}" ]; then
    if [ "$#" -gt 1 ]; then
        log_error "'${COMPONENT_NONE}' cannot be combined with component ids"
        exit 1
    fi
    _co_chosen=""
else
    for _co_id in "$@"; do
        components_validate "${_co_id}" || exit 1
    done
    _co_chosen="$(components_normalize "$@")"
fi

# ---------------------------------------------------------------------------
# Removal plan: recorded before, unchecked now. Never recorded → nothing.
# ---------------------------------------------------------------------------
_co_removed="$(components_removed "${_co_old}" "${_co_chosen}")"
_co_plan=""
if [ -n "${_co_removed}" ]; then
    # shellcheck disable=SC2086
    _co_plan="$(components_removal_plan "${_co_chosen}" ${_co_removed})"
fi

if [ -n "${_co_plan}" ]; then
    log_warn "Unchecking uninstalls. This will remove:"
    _co_ids="$(components_plan_ids "${_co_plan}" | tr '\n' ' ')"
    for _co_id in ${_co_ids}; do
        _co_lines="$(components_removal_lines "${_co_plan}" "${_co_id}")"
        [ -n "${_co_lines}" ] || continue
        printf '  %s\n' "${_co_id}" >&2
        printf '%s\n' "${_co_lines}" | while IFS= read -r _co_line; do
            printf '    %s\n' "${_co_line}" >&2
        done
    done
    if [ "${_co_yes}" -ne 1 ]; then
        if [ -t 0 ] && [ -t 1 ]; then
            # Only an explicit y goes on; n, enter, q, esc and end of input
            # all leave everything as it was.
            _co_rc=0
            tui_confirm "Remove the above and record the new selection?" n || _co_rc=$?
            if [ "${_co_rc}" -ne 0 ]; then
                log_warn "Cancelled: nothing removed, selection unchanged."
                exit "${_co_rc}"
            fi
        else
            log_error "This change removes components and there is no TTY to confirm: pass --yes. Nothing changed."
            exit 2
        fi
    fi
fi

# shellcheck disable=SC2086
components_apply ${_co_chosen} || exit 1

_co_failed=0
if [ -n "${_co_plan}" ]; then
    log_step "Removing unchecked components"
    # shellcheck disable=SC2086
    components_remove "${_co_plan}" ${_co_ids} || _co_failed=1
fi

# ---------------------------------------------------------------------------
# Success banner
# ---------------------------------------------------------------------------
if [ "${_co_failed}" -ne 0 ]; then
    log_warn "Selection recorded as ${_co_chosen:-${COMPONENT_NONE}}, but some removals failed (see warnings above)."
    exit 1
fi
_co_applied_at="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Components set" "${_co_chosen:-${COMPONENT_NONE}}" "Recorded as DOTS_COMPONENTS in ~/.config/zsh/local.zsh" "Applied at ${_co_applied_at}"
