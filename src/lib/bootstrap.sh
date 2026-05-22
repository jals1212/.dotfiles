#!/bin/sh
# lib/bootstrap.sh — first-run dependency bootstrap (idempotent)
# POSIX sh. Source this file; do not execute directly.
# Caller MUST have sourced lib/log.sh and lib/detect.sh and exported REPO_ROOT.

# ---------------------------------------------------------------------------
# bootstrap_check
#   Returns 0 when python3 + git + all vendored submodules are present.
#   Non-zero when any are missing — signal for bootstrap_ensure to do work.
# ---------------------------------------------------------------------------
bootstrap_check() {
    command -v python3 >/dev/null 2>&1 || return 1
    command -v git >/dev/null 2>&1 || return 1
    [ -x "${REPO_ROOT}/vendor/dotbot/bin/dotbot" ] || return 1
    [ -f "${REPO_ROOT}/vendor/plugins/dotbot-brew/brew.py" ] || return 1
    [ -f "${REPO_ROOT}/vendor/plugins/dotbot-mise/mise.py" ] || return 1
    return 0
}

# ---------------------------------------------------------------------------
# bootstrap_install_prereqs
#   Installs python3 + git + Linux build deps when missing.
#   On macOS without Xcode CLT: triggers xcode-select --install and exits 1.
# ---------------------------------------------------------------------------
bootstrap_install_prereqs() {
    _bip_os="$(detect_os)"
    case "${_bip_os}" in
        macos)
            if ! command -v git >/dev/null 2>&1 || ! command -v python3 >/dev/null 2>&1; then
                log_step "Triggering Xcode Command Line Tools install (git + python3)"
                xcode-select --install || true
                log_warn "Re-run ./dots once the Xcode CLT install dialog completes."
                exit 1
            fi
            ;;
        linux)
            if command -v python3 >/dev/null 2>&1 && command -v git >/dev/null 2>&1; then
                return 0
            fi
            if [ "$(id -u)" -eq 0 ]; then _bip_sudo=""; else _bip_sudo="sudo"; fi
            if command -v apt-get >/dev/null 2>&1; then
                log_step "Installing Linux build deps via apt-get"
                ${_bip_sudo} apt-get update -y
                ${_bip_sudo} apt-get install -y build-essential curl git python3 unzip fontconfig zsh
            elif command -v dnf >/dev/null 2>&1; then
                log_step "Installing Linux build deps via dnf"
                ${_bip_sudo} dnf install -y @development-tools curl file git python3 wget unzip fontconfig zsh
            elif command -v pacman >/dev/null 2>&1; then
                log_step "Installing Linux build deps via pacman"
                ${_bip_sudo} pacman -S --needed --noconfirm base-devel curl file git python wget unzip fontconfig zsh
            else
                log_error "No known package manager (apt-get/dnf/pacman). Install python3 + git manually and re-run ./dots."
                exit 1
            fi
            ;;
        *)
            log_error "Unsupported OS: ${_bip_os}"
            exit 1
            ;;
    esac
}

# ---------------------------------------------------------------------------
# bootstrap_init_submodules
#   Runs `git submodule update --init --recursive` only when any vendored
#   submodule entry point is missing.
# ---------------------------------------------------------------------------
bootstrap_init_submodules() {
    if [ -x "${REPO_ROOT}/vendor/dotbot/bin/dotbot" ] \
        && [ -f "${REPO_ROOT}/vendor/plugins/dotbot-brew/brew.py" ] \
        && [ -f "${REPO_ROOT}/vendor/plugins/dotbot-mise/mise.py" ]; then
        return 0
    fi
    log_step "Initializing git submodules (dotbot + plugins)"
    git -C "${REPO_ROOT}" submodule update --init --recursive
}

# ---------------------------------------------------------------------------
# bootstrap_ensure
#   Idempotent entry point: only does work when something is missing.
#   Called from lib/dotbot.sh:dotbot_check_submodules so every command that
#   touches dotbot auto-bootstraps on a fresh machine.
# ---------------------------------------------------------------------------
bootstrap_ensure() {
    if bootstrap_check; then
        return 0
    fi
    log_step "First-run setup detected"
    bootstrap_install_prereqs
    bootstrap_init_submodules
}
