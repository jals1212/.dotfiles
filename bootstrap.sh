#!/bin/sh
# bootstrap.sh — Dotfiles first-run bootstrap entry point.
# POSIX sh, set -eu.
# Usage: ./bootstrap.sh [--yes] [--theme=NAME] [--flavor=NAME]
#
# Chicken-and-egg only: ensures python3 + git + Linux build deps, materializes
# the dotbot/ and plugins/dotbot-{brew,mise} submodules, then hands off to
# `./dots update`. Homebrew install + brew bundle + mise install all happen
# inside dotbot directives in install.conf.yaml (NOT here).

set -eu

# ---------------------------------------------------------------------------
# Locate repo root
# ---------------------------------------------------------------------------
REPO_ROOT="$(cd "$(dirname "$0")" && pwd)"
export REPO_ROOT

# shellcheck source=lib/log.sh
. "${REPO_ROOT}/lib/log.sh"
# shellcheck source=lib/detect.sh
. "${REPO_ROOT}/lib/detect.sh"
# shellcheck source=lib/header.sh
. "${REPO_ROOT}/lib/header.sh"

# ---------------------------------------------------------------------------
# Args
# ---------------------------------------------------------------------------
YES=0
THEME=""
FLAVOR=""

usage() {
    cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Bootstrap dotfiles on a fresh macOS or Linux machine. Installs the bare
minimum needed to run dotbot (python3 + git + Linux build deps) and then
hands off to ./dots update --yes.

OPTIONS
  --yes              Non-interactive; pass --yes to ./dots update.
  --theme=NAME       Set theme without prompting. Supported: kanagawa, catppuccin.
  --flavor=NAME      Set flavor without prompting (e.g. dragon, mocha).
  -h, --help         Show this help and exit.

NOTES
  Homebrew install, brew bundle, and mise install are NOT done here.
  They run inside dotbot directives in install.conf.yaml when
  ./dots update invokes ./install.
EOF
}

while [ $# -gt 0 ]; do
    case "$1" in
        --yes)         YES=1 ;;
        --theme=*)     THEME="${1#--theme=}" ;;
        --flavor=*)    FLAVOR="${1#--flavor=}" ;;
        --tools=*)
            log_error "--tools flag is removed; declare tools in Brewfile or home/.config/mise/config.toml"
            exit 2
            ;;
        -h|--help)     usage; exit 0 ;;
        -*)            log_error "Unknown flag: $1"; usage >&2; exit 1 ;;
        *)             log_error "Unexpected argument: $1"; usage >&2; exit 1 ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Header
# ---------------------------------------------------------------------------
render_header "${THEME:-kanagawa}" "Dotfiles Bootstrap"

# ---------------------------------------------------------------------------
# OS detection
# ---------------------------------------------------------------------------
_os="$(detect_os)"
_arch="$(detect_arch)"
log_info "Detected: ${_os} (${_arch})"

# ---------------------------------------------------------------------------
# Chicken-and-egg: python3 + git + Linux build deps
# ---------------------------------------------------------------------------
_has() { command -v "$1" >/dev/null 2>&1; }

case "${_os}" in
    macos)
        if ! _has git || ! _has python3; then
            log_step "Triggering Xcode Command Line Tools install (git + python3)"
            xcode-select --install || true
            log_warn "Re-run ./bootstrap.sh after the Xcode CLT install completes."
            exit 1
        fi
        ;;
    linux)
        if [ "$(id -u)" -eq 0 ]; then _sudo=""; else _sudo="sudo"; fi
        if _has apt-get; then
            log_step "Installing Linux build deps via apt-get"
            ${_sudo} apt-get update -y
            ${_sudo} apt-get install -y build-essential curl git python3 unzip fontconfig zsh
        elif _has dnf; then
            log_step "Installing Linux build deps via dnf"
            ${_sudo} dnf install -y @development-tools curl file git python3 wget unzip fontconfig zsh
        elif _has pacman; then
            log_step "Installing Linux build deps via pacman"
            ${_sudo} pacman -S --needed --noconfirm base-devel curl file git python wget unzip fontconfig zsh
        else
            log_error "No known package manager (apt-get/dnf/pacman); install python3+git manually and re-run."
            exit 1
        fi
        ;;
    *)
        log_error "Unsupported OS: ${_os}"
        exit 1
        ;;
esac

# ---------------------------------------------------------------------------
# Materialize submodules
# ---------------------------------------------------------------------------
log_step "Initializing git submodules (dotbot + plugins)"
git -C "${REPO_ROOT}" submodule update --init --recursive

# ---------------------------------------------------------------------------
# Hand off to ./dots update
# ---------------------------------------------------------------------------
if [ ! -x "${REPO_ROOT}/dots" ]; then
    log_error "${REPO_ROOT}/dots dispatcher is missing or not executable."
    exit 1
fi

_yes_arg=""
[ "${YES}" = 1 ] && _yes_arg="--yes"

# shellcheck disable=SC2086
exec "${REPO_ROOT}/dots" update \
    ${_yes_arg} \
    ${THEME:+--theme="${THEME}"} \
    ${FLAVOR:+--flavor="${FLAVOR}"}
