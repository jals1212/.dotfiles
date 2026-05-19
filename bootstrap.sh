#!/bin/sh
# bootstrap.sh — Dotfiles first-run bootstrap entry point
# POSIX sh, set -eu.
# Usage: ./bootstrap.sh [--yes] [--theme=NAME] [--flavor=NAME] [--accent=NAME] [--tools=LIST]
#
# Forward dependencies (Sec 3–5):
#   ./dots select   — implemented by commands/select.sh (Sec 5.2)
#   ./dots apply    — implemented by commands/apply.sh  (Sec 5.3)
# When those files land, the forward-ref calls below naturally resolve.
# Until then, bootstrap falls back with a clear log_warn and exit 1.

set -eu

# ---------------------------------------------------------------------------
# Locate repo root relative to this script
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
export REPO_ROOT

# ---------------------------------------------------------------------------
# Source library modules
# ---------------------------------------------------------------------------
# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/detect.sh
. "${REPO_ROOT}/lib/detect.sh"
# shellcheck source=lib/header.sh
. "${REPO_ROOT}/lib/header.sh"
# shellcheck source=lib/brew.sh
. "${REPO_ROOT}/lib/brew.sh"

# ---------------------------------------------------------------------------
# Defaults
# ---------------------------------------------------------------------------
YES=0
THEME=""
FLAVOR=""
ACCENT=""
TOOLS=""

export NONINTERACTIVE=0

# ---------------------------------------------------------------------------
# Flag parsing (POSIX — no getopts for long flags; manual while loop)
# ---------------------------------------------------------------------------
usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap dotfiles on a fresh macOS or Linux machine.

Options:
  --yes              Non-interactive mode; skip all prompts, use committed defaults.
  --theme=NAME       Set theme without prompting. Supported: kanagawa, catppuccin.
  --flavor=NAME      Set flavor without prompting (e.g. dragon, mocha).
  --accent=NAME      Set accent without prompting (catppuccin only, e.g. mauve).
  --tools=A,B,C      Comma-separated tools to deploy without prompting.
  -h, --help         Show this help and exit.

Examples:
  ./bootstrap.sh
  ./bootstrap.sh --yes
  ./bootstrap.sh --theme=kanagawa --flavor=dragon --tools=zsh,tmux,nvim
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes)
            YES=1
            NONINTERACTIVE=1
            export NONINTERACTIVE
            ;;
        --theme=*)
            THEME="${1#--theme=}"
            ;;
        --flavor=*)
            FLAVOR="${1#--flavor=}"
            ;;
        --accent=*)
            ACCENT="${1#--accent=}"
            ;;
        --tools=*)
            TOOLS="${1#--tools=}"
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        -*)
            log_error "Unknown flag: $1"
            usage >&2
            exit 1
            ;;
        *)
            log_error "Unexpected argument: $1"
            usage >&2
            exit 1
            ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# 1. Render header
# ---------------------------------------------------------------------------
render_header "${THEME:-kanagawa}" "Dotfiles Bootstrap"

# ---------------------------------------------------------------------------
# 2. Detect OS (and arch) — log it
# ---------------------------------------------------------------------------
_os="$(detect_os)"
_arch="$(detect_arch)"
log_info "Detected: ${_os} (${_arch})"

# ---------------------------------------------------------------------------
# 3. Linux build dependencies
# ---------------------------------------------------------------------------
if [ "${_os}" = "linux" ]; then
    linux_deps
fi

# ---------------------------------------------------------------------------
# 4. Install Homebrew if missing
# ---------------------------------------------------------------------------
install_homebrew_if_missing

# ---------------------------------------------------------------------------
# 5. Load brew shellenv so subsequent steps see brew on PATH
# ---------------------------------------------------------------------------
load_brew_shellenv

# ---------------------------------------------------------------------------
# 6. Install packages via Brewfile
# ---------------------------------------------------------------------------
brew_bundle_install "${REPO_ROOT}/Brewfile"

# ---------------------------------------------------------------------------
# 7. Wizard (selection)
# Forward-ref: dots select (commands/select.sh, Sec 5.2)
# When --yes AND all of THEME/FLAVOR/TOOLS are set, skip prompts.
# ---------------------------------------------------------------------------
_skip_wizard=0
if [ "${YES}" = "1" ] && [ -n "${THEME}" ] && [ -n "${FLAVOR}" ] && [ -n "${TOOLS}" ]; then
    log_info "All theme/flavor/tools flags provided with --yes; skipping interactive wizard."
    _skip_wizard=1
fi

if [ "${_skip_wizard}" = "0" ]; then
    # Forward-ref: ./dots select is provided by Sec 5 (commands/select.sh via dots dispatcher).
    if [ -x "${REPO_ROOT}/dots" ]; then
        "${REPO_ROOT}/dots" select \
            ${THEME:+--theme="${THEME}"} \
            ${FLAVOR:+--flavor="${FLAVOR}"} \
            ${ACCENT:+--accent="${ACCENT}"} \
            ${TOOLS:+--tools="${TOOLS}"}
    else
        log_warn "Interactive wizard not yet available (./dots dispatcher pending Sec 5)."
        log_warn "Re-run after Sec 5 lands, or use: ./bootstrap.sh --yes --theme=kanagawa --flavor=dragon --tools=zsh,tmux,nvim,oh-my-posh,atuin,zoxide,ghostty"
        exit 1
    fi
fi

# ---------------------------------------------------------------------------
# 8. Confirm
# When YES=1, the wizard's confirm step is bypassed upstream (--yes propagated
# to dots select). Bootstrap does NOT duplicate confirmation here.
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# 9. Apply
# Forward-ref: ./dots apply is provided by Sec 5 (commands/apply.sh via dots dispatcher).
# ---------------------------------------------------------------------------
if [ -x "${REPO_ROOT}/dots" ]; then
    "${REPO_ROOT}/dots" apply
else
    log_warn "Apply not yet available (./dots dispatcher pending Sec 5)."
    log_warn "Re-run after Sec 5 lands, or run: ./dots apply"
    exit 1
fi
