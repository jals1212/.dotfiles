#!/usr/bin/env bats
# Verifies the Herdr theme bridge used by ./dots theme.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "_th_herdr_theme_name maps dots flavors to Herdr built-ins" {
    run _th_herdr_theme_name kanagawa dragon
    [ "${status}" -eq 0 ]
    [ "${output}" = "kanagawa" ]

    run _th_herdr_theme_name kanagawa lotus
    [ "${status}" -eq 0 ]
    [ "${output}" = "kanagawa-lotus" ]

    run _th_herdr_theme_name catppuccin mocha
    [ "${status}" -eq 0 ]
    [ "${output}" = "catppuccin" ]

    run _th_herdr_theme_name catppuccin latte
    [ "${status}" -eq 0 ]
    [ "${output}" = "catppuccin-latte" ]
}

@test "_th_apply_herdr_theme rewrites the Herdr theme fence" {
    f="${SANDBOX}/config.toml"
    cp "${REPO_ROOT_REAL}/content/home/.config/herdr/config.toml" "${f}"
    path_content_herdr_config() { printf '%s' "${f}"; }

    run _th_apply_herdr_theme catppuccin latte
    [ "${status}" -eq 0 ]
    grep -Fq 'name = "catppuccin-latte"' "${f}"
    ! grep -Fq 'name = "kanagawa"' "${f}"
    grep -Fq 'auto_switch = false' "${f}"
    [ "$(grep -c '# >>> dots:theme >>>' "${f}")" -eq 1 ]
    [ "$(grep -c '# <<< dots:theme <<<' "${f}")" -eq 1 ]
}
