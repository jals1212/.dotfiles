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
    printf '  --yes             Non-interactive: skip pickers, apply immediately.\n' >&2
    printf '  --theme=NAME      Override active theme (e.g. kanagawa, catppuccin).\n' >&2
    printf '  --flavor=NAME     Override active flavor (e.g. dragon, mocha).\n' >&2
    printf '  --pull            Run git pull --ff-only against upstream before\n' >&2
    printf '                    invoking dotbot. Aborts on non-fast-forward or\n' >&2
    printf '                    missing upstream; does not touch the remote otherwise.\n' >&2
    printf '  --help / -h       Show this message.\n\n' >&2
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

# shellcheck source=src/lib/log.sh
. "${REPO_ROOT}/src/lib/log.sh"
# shellcheck source=src/lib/tui.sh
. "${REPO_ROOT}/src/lib/tui.sh"
# shellcheck source=src/lib/header.sh
. "${REPO_ROOT}/src/lib/header.sh"
# shellcheck source=src/lib/dotbot.sh
. "${REPO_ROOT}/src/lib/dotbot.sh"
# shellcheck source=src/lib/theme.sh
. "${REPO_ROOT}/src/lib/theme.sh"
# shellcheck source=src/lib/select.sh
. "${REPO_ROOT}/src/lib/select.sh"
# shellcheck source=src/lib/detect.sh
. "${REPO_ROOT}/src/lib/detect.sh"

tui_start_timer
render_subcommand_banner "$(tui_subtitle_for update)"

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
        --*)
            log_error "Unknown flag: ${_arg}"
            exit 1
            ;;
    esac
done

if [ "${YES:-0}" = "1" ]; then
    _yes=1
fi

# First-run + missing gum → force --yes (the wizard depends on gum, which
# brew bundle will install during dotbot_base_apply). Subsequent runs are
# fully interactive.
if [ ! -f "${REPO_ROOT}/manifest.json" ] && ! command -v gum >/dev/null 2>&1; then
    if [ "${_yes}" -eq 0 ]; then
        log_warn "First-run: gum not installed yet; applying defaults non-interactively. Run ./dots theme later to switch."
        _yes=1
    fi
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
    gum style \
        --border rounded \
        --border-foreground "$(_header_color_code "${_active_theme}")" \
        --padding "1 2" \
        --bold \
        "Current active theme
Theme:  ${_active_theme}
Flavor: ${_active_flavor}"

    if gum confirm --default=false "Change theme?"; then
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
# Base dotbot run
# ---------------------------------------------------------------------------
log_step "Running base dotbot config..."
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
# Success
# ---------------------------------------------------------------------------
_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
log_success "Update complete" \
    "${_active_theme}/${_active_flavor} applied at ${_ts}"
