#!/bin/sh
# lib/dotbot.sh — dotbot orchestration helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh sourced before this file.

# ---------------------------------------------------------------------------
# dotbot_check_submodules
#   Ensure dotbot and plugin submodules are initialized (auto-bootstraps the
#   chicken-and-egg prereqs on a fresh machine via lib/bootstrap.sh), then
#   verifies the entry points are reachable. Returns 0 if all present, 1
#   with log_error if any are missing after the bootstrap attempt.
# ---------------------------------------------------------------------------
dotbot_check_submodules() {
    # Auto-bootstrap python3 + git + Linux build deps + submodules on first run.
    if [ -f "${REPO_ROOT}/src/lib/bootstrap.sh" ]; then
        # shellcheck source=src/lib/bootstrap.sh
        . "${REPO_ROOT}/src/lib/bootstrap.sh"
        bootstrap_ensure
    fi

    _dcs_ok=1

    if [ ! -x "${REPO_ROOT}/vendor/dotbot/bin/dotbot" ]; then
        log_error "dotbot submodule not initialized; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    if [ ! -f "${REPO_ROOT}/vendor/plugins/dotbot-brew/brew.py" ]; then
        log_error "dotbot-brew plugin missing; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    if [ ! -f "${REPO_ROOT}/vendor/plugins/dotbot-mise/mise.py" ]; then
        log_error "dotbot-mise plugin missing; run: git submodule update --init --recursive"
        _dcs_ok=0
    fi

    [ "${_dcs_ok}" -eq 1 ] || return 1
}

# ---------------------------------------------------------------------------
# dotbot_base_apply
#   Run the base dotbot config (install.conf.yaml) via the ./install wrapper.
#   Returns the wrapper's exit status.
# ---------------------------------------------------------------------------
dotbot_base_apply() {
    dotbot_check_submodules || return 1
    log_step "Running base dotbot config (install.conf.yaml)"
    "${REPO_ROOT}/src/install"
}

# ---------------------------------------------------------------------------
# dotbot_theme_apply <theme> <flavor>
#   Run the per-theme dotbot config for the given theme/flavor pair.
#   Returns the wrapper's exit status.
# ---------------------------------------------------------------------------
dotbot_theme_apply() {
    _dta_theme="${1:?dotbot_theme_apply: theme required}"
    _dta_flavor="${2:?dotbot_theme_apply: flavor required}"

    dotbot_check_submodules || return 1

    _dta_config="${REPO_ROOT}/content/themes/${_dta_theme}-${_dta_flavor}.yaml"
    if [ ! -f "${_dta_config}" ]; then
        log_error "Per-theme config not found: themes/${_dta_theme}-${_dta_flavor}.yaml"
        return 1
    fi

    log_step "Applying theme config: themes/${_dta_theme}-${_dta_flavor}.yaml"
    "${REPO_ROOT}/src/install" "themes/${_dta_theme}-${_dta_flavor}.yaml"
}
