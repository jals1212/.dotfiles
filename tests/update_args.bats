#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/update_args.bats
# `dots update` rejects unknown arguments before doing any work, and keeps its
# documented flags working. dotbot is stubbed in a sandbox copy of the repo.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    REPO="${SANDBOX}/repo"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin" "${REPO}"
    cp -R "${REPO_ROOT_REAL}/src" "${REPO_ROOT_REAL}/content" "${REPO}/"
    cp "${REPO_ROOT_REAL}/dots" "${REPO}/dots"
    export CALLS="${SANDBOX}/calls.log"
    : > "${CALLS}"

    printf '%s\n' \
        'dotbot_base_apply() { echo base >> "${CALLS}"; return 0; }' \
        'dotbot_check_submodules() { return 0; }' \
        'dotbot_theme_apply() { echo theme >> "${CALLS}"; return 0; }' \
        >> "${REPO}/src/lib/dotbot.sh"
    # brew succeeds for everything, so `brew list --cask` reports the font
    # installed and the host's Homebrew is never touched.
    printf '#!/bin/sh\nexit 0\n' > "${SANDBOX}/bin/brew"; chmod +x "${SANDBOX}/bin/brew"
    for tool in bat tmux herdr; do printf '#!/bin/sh\nexit 1\n' > "${SANDBOX}/bin/${tool}"; chmod +x "${SANDBOX}/bin/${tool}"; done
    export PATH="${SANDBOX}/bin:${PATH}"
    export NO_COLOR=1
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "update rejects a bare positional argument naming it, exit 2, running nothing" {
    run --separate-stderr sh "${REPO}/dots" update bogus

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"bogus"* ]] || return 1
    [ ! -s "${CALLS}" ]
    [ ! -e "${REPO}/manifest.json" ]
}

@test "update rejects unknown long and single-dash flags with exit 2, running nothing" {
    for arg in --bogus -z --theme; do
        run --separate-stderr sh "${REPO}/dots" update --yes "${arg}"

        [ "${status}" -eq 2 ]
        [[ "${stderr}" == *"${arg}"* ]] || return 1
        [ ! -s "${CALLS}" ]
        [ ! -e "${REPO}/manifest.json" ]
    done
}

@test "update keeps its documented flags working" {
    run --separate-stderr sh "${REPO}/dots" update --yes --theme=catppuccin --flavor=mocha

    [ "${status}" -eq 0 ]
    grep -q base "${CALLS}"
    grep -Fq '"theme": "catppuccin"' "${REPO}/manifest.json"
    grep -Fq '"flavor": "mocha"' "${REPO}/manifest.json"

    run --separate-stderr sh "${REPO}/dots" update -y
    [ "${status}" -eq 0 ]

    run --separate-stderr sh "${REPO}/dots" update --help
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"--pull"* ]]
}

@test "update still refuses --tools with exit 2" {
    run --separate-stderr sh "${REPO}/dots" update --tools=x

    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"--tools is not accepted"* ]]
}

@test "update --yes applies the default font, then keeps a recorded choice" {
    run --separate-stderr sh "${REPO}/dots" update --yes
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.config/ghostty/font.conf")" = 'font-family = "JetBrainsMono Nerd Font"' ]

    sh "${REPO}/dots" font iosevka >/dev/null
    run --separate-stderr sh "${REPO}/dots" update --yes
    [ "${status}" -eq 0 ]
    [ "$(cat "${HOME}/.config/ghostty/font.conf")" = 'font-family = "IosevkaTerm NF"' ]
}
