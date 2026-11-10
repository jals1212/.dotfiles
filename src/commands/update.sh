#!/bin/sh
# commands/update.sh — full deploy: base dotbot + theme switcher
# POSIX sh. Invoked by the dots dispatcher or directly.
set -eu

# ---------------------------------------------------------------------------
# Help
# ---------------------------------------------------------------------------
_update_usage() {
    printf 'dots update - full deploy: ./install (base dotbot) + theme switcher\n\n' >&2
    printf 'USAGE\n' >&2
    printf '  ./dots update [--yes] [--theme=NAME] [--flavor=NAME] [--pull]\n\n' >&2
    printf 'BEHAVIOR\n' >&2
    printf '  Runs ./install (base dotbot config), then applies the active or\n' >&2
    printf '  selected theme. Theme/flavor are read from manifest.json when\n' >&2
    printf '  present; flags override; hardcoded defaults apply on first run.\n\n' >&2
    printf 'FLAGS\n' >&2
    printf '  --yes             Non-interactive: skip pickers (theme, font, components),\n' >&2
    printf '                    apply immediately.\n' >&2
    printf '  --theme=NAME      Override active theme (e.g. kanagawa, catppuccin).\n' >&2
    printf '  --flavor=NAME     Override active flavor (e.g. dragon, mocha).\n' >&2
    printf '  --pull            Run git pull --ff-only against upstream before\n' >&2
    printf '                    invoking dotbot. Aborts on non-fast-forward or\n' >&2
    printf '                    missing upstream; does not touch the remote otherwise.\n' >&2
    printf '  --help / -h       Show this message.\n\n' >&2
    printf 'On a TTY, update also asks once for the terminal components (tmux,\n' >&2
    printf 'Herdr, Ghostty) while none is recorded; choose them later with\n' >&2
    printf './dots components. --yes never asks.\n\n' >&2
    printf 'On macOS with herdr-app selected, an official Herdr app install\n' >&2
    printf '(~/Applications/Herdr.app) is removed before Homebrew installs the\n' >&2
    printf 'herdr-app cask, after a [y/N] question (--yes removes it; no TTY keeps\n' >&2
    printf 'it). The core stays; a running app is never removed.\n\n' >&2
    printf 'Any other argument is an error (exit 2); nothing runs.\n\n' >&2
    printf 'NOTE\n' >&2
    printf '  --tools is not accepted. Managed packages are declared in Brewfile\n' >&2
    printf '  and home/.config/mise/config.toml.\n' >&2
}

if [ "${1:-}" = "--help" ] || [ "${1:-}" = "-h" ]; then
    _update_usage
    exit 0
fi

# ---------------------------------------------------------------------------
# Compute REPO_ROOT and source libs
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
# shellcheck source=src/lib/dotbot.sh
. "$(path_src_lib dotbot.sh)"
# shellcheck source=src/lib/theme.sh
. "$(path_src_lib theme.sh)"
# shellcheck source=src/lib/select.sh
. "$(path_src_lib select.sh)"
# shellcheck source=src/lib/detect.sh
. "$(path_src_lib detect.sh)"
# shellcheck source=src/lib/font.sh
. "$(path_src_lib font.sh)"
# shellcheck source=src/lib/components.sh
. "$(path_src_lib components.sh)"

# ---------------------------------------------------------------------------
# Parse flags
# ---------------------------------------------------------------------------
_yes=0
_arg_theme=""
_arg_flavor=""
_do_pull=0

for _arg in "$@"; do
    case "${_arg}" in
        --yes|-y)    _yes=1 ;;
        --pull)      _do_pull=1 ;;
        --theme=*)   _arg_theme="${_arg#--theme=}" ;;
        --flavor=*)  _arg_flavor="${_arg#--flavor=}" ;;
        --tools=*)
            log_error "--tools is not accepted. Managed packages are declared in Brewfile and home/.config/mise/config.toml."
            exit 2
            ;;
        --help|-h)
            _update_usage
            exit 0
            ;;
        *)
            log_error "Unknown argument: ${_arg} (see ./dots update --help)"
            exit 2
            ;;
    esac
done

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for update)"

if [ "${YES:-0}" = "1" ]; then
    _yes=1
fi

# ---------------------------------------------------------------------------
# --pull: fast-forward pull before any dotbot work
# ---------------------------------------------------------------------------
if [ "${_do_pull}" -eq 1 ]; then
    # Detect detached HEAD
    if ! git -C "${REPO_ROOT}" symbolic-ref -q HEAD >/dev/null 2>&1; then
        # Fallback: check via branch --show-current (git >= 2.22)
        _cur_branch="$(git -C "${REPO_ROOT}" branch --show-current 2>/dev/null || printf '')"
        if [ -z "${_cur_branch}" ]; then
            log_error "--pull requires a branch with an upstream; current HEAD is detached"
            exit 1
        fi
    fi

    # Detect missing upstream
    if ! git -C "${REPO_ROOT}" rev-parse --abbrev-ref "@{upstream}" >/dev/null 2>&1; then
        log_error "no upstream configured; set one via: git branch --set-upstream-to=<remote>/<branch>"
        exit 1
    fi

    log_step "Pulling upstream changes (--ff-only)..."
    if ! git -C "${REPO_ROOT}" pull --ff-only; then
        log_error "git pull --ff-only failed; resolve divergence before running update"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# Read active theme/flavor from manifest (slim schema) or fall back to defaults
# ---------------------------------------------------------------------------
_active_theme="kanagawa"
_active_flavor="dragon"

_manifest_pair="$(theme_current 2>/dev/null || printf '')"
if [ -n "${_manifest_pair}" ]; then
    _active_theme="$(printf '%s' "${_manifest_pair}" | awk '{print $1}')"
    _active_flavor="$(printf '%s' "${_manifest_pair}" | awk '{print $2}')"
fi

# Apply flag overrides
if [ -n "${_arg_theme}" ]; then
    _active_theme="${_arg_theme}"
fi
if [ -n "${_arg_flavor}" ]; then
    _active_flavor="${_arg_flavor}"
fi

# ---------------------------------------------------------------------------
# Interactive selection (TTY, no --yes, no flag overrides)
# ---------------------------------------------------------------------------
if [ "${_yes}" -eq 0 ] && [ -z "${_arg_theme}" ] && [ -z "${_arg_flavor}" ] && [ -t 0 ] && [ -t 1 ]; then
    # Summary card for the active manifest/default values. Pressing Enter at
    # the following default-No prompt re-applies these values (former sync).
    tui_card "$(_header_color_code "${_active_theme}")" "Current active theme" \
        "Theme:  ${_active_theme}" "Flavor: ${_active_flavor}"

    if tui_confirm "Change theme?" n; then
        _active_theme="$(select_theme "${REPO_ROOT}" "${_active_theme}")"
        _active_flavor="$(select_flavor "${REPO_ROOT}" "${_active_theme}" "${_active_flavor}")"

        if ! confirm_apply "${_active_theme}" "${_active_flavor}"; then
            log_warn "Update cancelled."
            exit 1
        fi
    else
        _change_theme_status=$?
        if [ "${_change_theme_status}" -gt 1 ]; then
            log_warn "Update cancelled."
            exit 1
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Font: the recorded machine-local choice; asked once on a TTY when none is
# recorded yet (first install). Change it later with ./dots font.
# ---------------------------------------------------------------------------
_active_font="$(font_current)"
if [ "${_yes}" -eq 0 ] && [ -z "$(font_recorded)" ] && [ -t 0 ] && [ -t 1 ]; then
    _active_font="$(select_font "${_active_font}")"
fi

# ---------------------------------------------------------------------------
# Components: the recorded machine-local selection; asked once on a TTY while
# none is recorded (first install), then recorded. --yes never asks and never
# records. Change it later with ./dots components.
# ---------------------------------------------------------------------------
if [ "${_yes}" -eq 0 ] && [ -z "$(components_recorded)" ] && [ -t 0 ] && [ -t 1 ]; then
    _chosen_components="$(select_components "")" || {
        log_warn "Update cancelled."
        exit 130
    }
    # shellcheck disable=SC2086
    components_apply ${_chosen_components} || {
        log_error "Recording the component selection failed"
        exit 1
    }
fi

# ---------------------------------------------------------------------------
# Herdr app on macOS comes from Homebrew: move an official install out of the
# way before the Brewfile runs (asks; --yes moves it; no TTY keeps it).
# ---------------------------------------------------------------------------
components_herdr_app_migrate "${_yes}" || log_warn "Moving Herdr app to Homebrew left something in place"

# ---------------------------------------------------------------------------
# Base dotbot run
# ---------------------------------------------------------------------------
dotbot_base_apply || {
    log_error "Base dotbot apply failed"
    exit 1
}

# ---------------------------------------------------------------------------
# Theme apply
# ---------------------------------------------------------------------------
log_step "Applying theme: ${_active_theme}/${_active_flavor}..."
theme_apply "${_active_theme}" "${_active_flavor}" || {
    log_error "Theme apply failed"
    exit 1
}

# ---------------------------------------------------------------------------
# Font apply
# ---------------------------------------------------------------------------
log_step "Applying font: ${_active_font}..."
font_apply "${_active_font}" || {
    log_error "Font apply failed"
    exit 1
}

# ---------------------------------------------------------------------------
# Success
# ---------------------------------------------------------------------------
_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Update complete" \
    "${_active_theme}/${_active_flavor} applied at ${_ts}"
