#!/usr/bin/env bats
# tests/dotbot_managed_dirs.bats
# Verifies Dotbot-managed directory discovery derives from Dotbot configs.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}"
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/dotbot.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "dotbot_managed_dirs derives base and theme destination directories" {
    run dotbot_managed_dirs

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${HOME}"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/lua"* ]]
    [[ "${output}" == *"${HOME}/.config/ghostty/themes"* ]]
    [[ "${output}" == *"${HOME}/.config/bat/themes"* ]]
    [[ "${output}" != *"content/assets"* ]]
}
