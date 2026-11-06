#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/theme_command.bats
# Runs `dots theme` end to end against a sandbox copy of the repo: the dotbot
# wrapper is stubbed, so nothing is linked and no repo file is rewritten.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin" "${SANDBOX}/repo"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO_ROOT_REAL}/content" "${SANDBOX}/repo/"
    cp "${REPO_ROOT_REAL}/dots" "${SANDBOX}/repo/dots"

    # Replace the real dotbot run with a no-op, in the sandbox copy only.
    printf '%s\n' \
        'dotbot_check_submodules() { return 0; }' \
        'dotbot_theme_apply() { return 0; }' \
        >> "${SANDBOX}/repo/src/lib/dotbot.sh"

    # Keep host tools (bat cache, tmux, herdr) out of the run.
    printf '#!/bin/sh\nexit 0\n' > "${SANDBOX}/bin/bat"
    printf '#!/bin/sh\nexit 1\n' > "${SANDBOX}/bin/tmux"
    printf '#!/bin/sh\nexit 1\n' > "${SANDBOX}/bin/herdr"
    chmod +x "${SANDBOX}/bin/bat" "${SANDBOX}/bin/tmux" "${SANDBOX}/bin/herdr"
    export PATH="${SANDBOX}/bin:${PATH}"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "dots theme <theme> <flavor> reports 'Theme set' exactly once" {
    run --separate-stderr sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin mocha
    all="${output}"$'\n'"${stderr}"
    echo "${all}"

    [ "${status}" -eq 0 ]
    [ "$(printf '%s\n' "${all}" | grep -c 'Theme set')" -eq 1 ]
    [[ "${all}" == *"catppuccin/mocha"* ]]
    grep -Fq '"theme": "catppuccin"' "${SANDBOX}/repo/manifest.json"
    grep -Fq '"flavor": "mocha"' "${SANDBOX}/repo/manifest.json"
}

@test "dots theme rejects an unknown flavor without writing a manifest" {
    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin nope

    [ "${status}" -ne 0 ]
    [ ! -e "${SANDBOX}/repo/manifest.json" ]
}
