#!/bin/sh
# bootstrap.sh — Dotfiles first-run bootstrap entry point
# POSIX sh, set -eu.
# Usage: ./bootstrap.sh [--yes] [--theme=NAME] [--flavor=NAME] [--accent=NAME] [--tools=LIST]
#
# Flow: header → OS detect → Linux deps (if needed) → Homebrew install →
#       brew bundle → `./dots select` (which runs the full deploy pipeline).

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
  --yes              Non-interactive mode; skip all prompts, use manifest or hardcoded defaults.
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
# 7. Run ./dots select — wizard + full deploy pipeline in one step.
# With --yes plus all theme/flavor/tools flags, select skips prompts.
# ---------------------------------------------------------------------------
if [ ! -x "${REPO_ROOT}/dots" ]; then
    log_error "${REPO_ROOT}/dots dispatcher is missing or not executable."
    exit 1
fi

_yes_arg=""
[ "${YES}" = "1" ] && _yes_arg="--yes"

"${REPO_ROOT}/dots" select \
    ${_yes_arg} \
    ${THEME:+--theme="${THEME}"} \
    ${FLAVOR:+--flavor="${FLAVOR}"} \
    ${ACCENT:+--accent="${ACCENT}"} \
    ${TOOLS:+--tools="${TOOLS}"}
