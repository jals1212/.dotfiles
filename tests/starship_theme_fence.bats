#!/usr/bin/env bats
# tests/starship_theme_fence.bats
# Verifies the dots:theme fence rewrite that switches the active starship palette.

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

@test "_th_apply_fence rewrites the active palette in the shipped config" {
    f="${SANDBOX}/starship.toml"
    cp "${REPO_ROOT_REAL}/content/home/.config/starship.toml" "${f}"

    run _th_apply_fence "${f}" 'palette = "catppuccin_mocha"' '^[[]'
    [ "${status}" -eq 0 ]
    grep -Fq 'palette = "catppuccin_mocha"' "${f}"
    ! grep -Fq 'palette = "kanagawa_dragon"' "${f}"

    [ "$(grep -c '# >>> dots:theme >>>' "${f}")" -eq 1 ]
    [ "$(grep -c '# <<< dots:theme <<<' "${f}")" -eq 1 ]
}

@test "_th_apply_fence inserts a fence when none exists" {
    f="${SANDBOX}/no-fence.toml"
    printf '[directory]\nstyle = "blue"\n' > "${f}"

    run _th_apply_fence "${f}" 'palette = "kanagawa_wave"' '^[[]'
    [ "${status}" -eq 0 ]
    [ "$(grep -c '# >>> dots:theme >>>' "${f}")" -eq 1 ]
    grep -Fq 'palette = "kanagawa_wave"' "${f}"
}
