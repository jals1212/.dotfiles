#!/bin/sh
# lib/brew.sh — Homebrew and Linux dependency helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh and lib/detect.sh sourced before this file.

# ---------------------------------------------------------------------------
# install_homebrew_if_missing
#   Installs Homebrew when `brew` is not found on PATH.
#   Respects NONINTERACTIVE=1: caller sets this when --yes is passed.
# ---------------------------------------------------------------------------
install_homebrew_if_missing() {
    if has_command brew; then
        log_info "Homebrew already installed."
        return 0
    fi

    # Also check well-known prefixes in case brew exists but is not on PATH
    for _p in /opt/homebrew/bin/brew /usr/local/bin/brew /home/linuxbrew/.linuxbrew/bin/brew; do
        if [ -x "${_p}" ]; then
            log_info "Homebrew found at ${_p} but not on PATH. Loading shellenv."
            eval "$("${_p}" shellenv)"
            return 0
        fi
    done

    _brew_install_script="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"
    log_step "Installing Homebrew..."

    if [ "${NONINTERACTIVE:-0}" = "1" ]; then
        NONINTERACTIVE=1 /bin/bash -c "$(curl -fsSL "${_brew_install_script}")"
    else
        /bin/bash -c "$(curl -fsSL "${_brew_install_script}")"
    fi

    # shellcheck disable=SC2181
    if [ $? -ne 0 ]; then
        log_error "Homebrew installation failed. Install missing build dependencies and retry."
        exit 1
    fi
}

# ---------------------------------------------------------------------------
# load_brew_shellenv
#   Evaluates `brew shellenv` from the canonical prefix so `brew` is on PATH.
#   Uses brew_prefix from lib/detect.sh.
# ---------------------------------------------------------------------------
load_brew_shellenv() {
    _prefix="$(brew_prefix)"

    if [ -x "${_prefix}/bin/brew" ]; then
        eval "$("${_prefix}/bin/brew" shellenv)"
    elif has_command brew; then
        # brew already on PATH; nothing to do
        :
    else
        log_warn "brew not found at expected prefix (${_prefix})"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# brew_bundle_install [brewfile_path]
#   Runs `brew bundle --file=<path>`.
#   Defaults to ${REPO_ROOT}/Brewfile or $(pwd)/Brewfile if REPO_ROOT unset.
# ---------------------------------------------------------------------------
brew_bundle_install() {
    _brewfile="${1:-${REPO_ROOT:-$(pwd)}/Brewfile}"
    log_step "Running brew bundle (${_brewfile})..."
    brew bundle --file="${_brewfile}"
}

# ---------------------------------------------------------------------------
# linux_deps
#   Installs distribution-appropriate build dependencies before Homebrew.
#   Detects package manager in order: apt-get → dnf → pacman.
#   Honors NONINTERACTIVE=1 by passing -y / --noconfirm flags.
#   No-ops (with a warning) when no known package manager is found.
# ---------------------------------------------------------------------------
linux_deps() {
    log_step "Installing Linux build dependencies..."

    # Determine sudo prefix (skip if already root)
    if [ "$(id -u)" -eq 0 ]; then
        _sudo=""
    else
        _sudo="sudo"
    fi

    if has_command apt-get; then
        _apt_flags="-y"
        ${_sudo} apt-get update -y
        ${_sudo} apt-get install ${_apt_flags} build-essential curl git unzip fontconfig
    elif has_command dnf; then
        _dnf_flags="-y"
        ${_sudo} dnf install ${_dnf_flags} @development-tools curl file git wget unzip fontconfig
    elif has_command pacman; then
        _pacman_flags="--needed"
        if [ "${NONINTERACTIVE:-0}" = "1" ]; then
            _pacman_flags="${_pacman_flags} --noconfirm"
        fi
        # shellcheck disable=SC2086
        ${_sudo} pacman -S ${_pacman_flags} base-devel curl file git wget unzip fontconfig
    else
        log_warn "No known package manager found (apt-get / dnf / pacman). Skipping Linux deps."
    fi
}
