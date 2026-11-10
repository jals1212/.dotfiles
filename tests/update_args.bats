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

# --- component picker (asked once, recorded; installs are not gated here) ---

_require_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

# _tty_update <keys> — `dots update` on a pty, keys (printf format) on fd 3.
_tty_update() {
    printf "$1" > "${SANDBOX}/keys"
    script -q /dev/null sh -c 'exec 3<"$1"; exec sh "$2" update' _ "${SANDBOX}/keys" "${REPO}/dots"
}

@test "update --yes never asks for components and records nothing" {
    run --separate-stderr sh "${REPO}/dots" update --yes
    [ "${status}" -eq 0 ]
    run grep -q DOTS_COMPONENTS "${HOME}/.config/zsh/local.zsh"
    [ "${status}" -ne 0 ]
}

@test "update --yes keeps a recorded component selection" {
    sh "${REPO}/dots" components tmux ghostty >/dev/null
    run --separate-stderr sh "${REPO}/dots" update --yes
    [ "${status}" -eq 0 ]
    run sh "${REPO}/dots" components --current
    [ "${output}" = "tmux ghostty" ]
}

@test "update on a TTY asks the component checklist once and records the choice" {
    _require_script || skip "PTY script syntax unavailable"
    sh "${REPO}/dots" font iosevka >/dev/null

    # Keys: Change theme? -> enter (No); checklist: toggle tmux, enter.
    run _tty_update '\n \n'
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux}"' "${HOME}/.config/zsh/local.zsh"
    grep -q base "${CALLS}"

    # Second run: a selection is recorded, so only Change theme? reads keys.
    cp "${HOME}/.config/zsh/local.zsh" "${SANDBOX}/local.before"
    run _tty_update '\n'
    [ "${status}" -eq 0 ]
    cmp -s "${HOME}/.config/zsh/local.zsh" "${SANDBOX}/local.before"
}

@test "update on a TTY: an empty checklist is recorded as none and not asked again" {
    _require_script || skip "PTY script syntax unavailable"
    sh "${REPO}/dots" font iosevka >/dev/null

    run _tty_update '\n\n'
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${HOME}/.config/zsh/local.zsh"

    run _tty_update '\n'
    [ "${status}" -eq 0 ]
}

@test "update on a TTY: cancelling the checklist stops before any work and records nothing" {
    _require_script || skip "PTY script syntax unavailable"
    sh "${REPO}/dots" font iosevka >/dev/null

    run _tty_update '\nq'
    [ "${status}" -eq 130 ]
    [ ! -s "${CALLS}" ]
    run grep -q DOTS_COMPONENTS "${HOME}/.config/zsh/local.zsh"
    [ "${status}" -ne 0 ]
}

@test "update --help documents the component ask" {
    run --separate-stderr sh "${REPO}/dots" update --help
    [ "${status}" -eq 0 ]
    [[ "${stderr}" == *"components"* ]]
}
