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

@test "dots theme writes the slim manifest with every key" {
    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa wave

    [ "${status}" -eq 0 ]
    manifest="${SANDBOX}/repo/manifest.json"
    grep -Fq '"version": "' "${manifest}"
    grep -Fq '"theme": "kanagawa"' "${manifest}"
    grep -Fq '"flavor": "wave"' "${manifest}"
    grep -Fq '"prompt": "starship"' "${manifest}"
    grep -Eq '"applied_at": "[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9:]{8}Z"' "${manifest}"
    [ "$(grep -c '":' "${manifest}")" -eq 5 ]
}

@test "dots theme keeps the manifest prompt and replaces theme and flavor" {
    printf '{\n  "version": "3.1.0",\n  "theme": "kanagawa",\n  "flavor": "wave",\n  "prompt": "p10k",\n  "applied_at": "2020-01-01T00:00:00Z"\n}\n' \
        > "${SANDBOX}/repo/manifest.json"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin latte

    [ "${status}" -eq 0 ]
    manifest="${SANDBOX}/repo/manifest.json"
    grep -Fq '"theme": "catppuccin"' "${manifest}"
    grep -Fq '"flavor": "latte"' "${manifest}"
    grep -Fq '"prompt": "p10k"' "${manifest}"
    run ! grep -Fq '2020-01-01' "${manifest}"
}

@test "dots theme --current prints the pair recorded in the manifest" {
    sh "${SANDBOX}/repo/src/commands/theme.sh" catppuccin frappe >/dev/null 2>&1

    run --separate-stderr sh "${SANDBOX}/repo/src/commands/theme.sh" --current

    [ "${status}" -eq 0 ]
    [ "${output}" = "catppuccin frappe" ]
}

@test "dots theme with an unknown theme or flavor leaves an existing manifest unchanged" {
    manifest="${SANDBOX}/repo/manifest.json"
    printf '{\n  "version": "3.1.0",\n  "theme": "kanagawa",\n  "flavor": "wave",\n  "prompt": "p10k",\n  "applied_at": "2020-01-01T00:00:00Z"\n}\n' \
        > "${manifest}"
    cp "${manifest}" "${SANDBOX}/manifest.before"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" nosuchtheme dragon
    [ "${status}" -ne 0 ]
    cmp "${manifest}" "${SANDBOX}/manifest.before"

    run sh "${SANDBOX}/repo/src/commands/theme.sh" kanagawa mocha
    [ "${status}" -ne 0 ]
    cmp "${manifest}" "${SANDBOX}/manifest.before"
}
