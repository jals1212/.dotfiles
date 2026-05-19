#!/usr/bin/env bats
# tests/deploy_apply_template.bats
# bats-core unit tests for deploy_apply_template in lib/deploy.sh.
# Requires: bats-core, shellcheck (lint gate), sh.
# Run: bats tests/deploy_apply_template.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # Source libs needed by deploy.sh
    # shellcheck source=../lib/log.sh
    . "${REPO_ROOT}/lib/log.sh"
    # shellcheck source=../lib/detect.sh
    . "${REPO_ROOT}/lib/detect.sh"
    # shellcheck source=../lib/deploy.sh
    . "${REPO_ROOT}/lib/deploy.sh"

    # Sandbox home dir for each test
    SANDBOX_HOME="$(mktemp -d)"
    export HOME="${SANDBOX_HOME}"

    # Create a minimal target file with template tokens
    mkdir -p "${HOME}/.config/zsh"
    printf 'theme=DOTS_THEME flavor=DOTS_FLAVOR combo=DOTS_THEME_FLAVOR\n' \
        > "${HOME}/.config/zsh/.zshrc"
}

teardown() {
    rm -rf "${SANDBOX_HOME}"
}

@test "deploy_apply_template substitutes theme and flavor tokens" {
    deploy_apply_template "${REPO_ROOT}" kanagawa dragon ""

    result="$(cat "${HOME}/.config/zsh/.zshrc")"
    [ "${result}" = "theme=kanagawa flavor=dragon combo=kanagawa/dragon" ]
}

@test "deploy_apply_template is idempotent on second run" {
    deploy_apply_template "${REPO_ROOT}" kanagawa dragon ""
    first="$(cat "${HOME}/.config/zsh/.zshrc")"

    deploy_apply_template "${REPO_ROOT}" kanagawa dragon ""
    second="$(cat "${HOME}/.config/zsh/.zshrc")"

    [ "${first}" = "${second}" ]
}

@test "deploy_apply_template supports catppuccin flavor" {
    printf 'theme=DOTS_THEME flavor=DOTS_FLAVOR combo=DOTS_THEME_FLAVOR\n' \
        > "${HOME}/.config/zsh/.zshrc"

    deploy_apply_template "${REPO_ROOT}" catppuccin mocha ""

    result="$(cat "${HOME}/.config/zsh/.zshrc")"
    [ "${result}" = "theme=catppuccin flavor=mocha combo=catppuccin/mocha" ]
}
