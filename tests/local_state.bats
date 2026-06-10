#!/usr/bin/env bats
# tests/local_state.bats
# Verifies the machine-local state file (~/.config/zsh/local.zsh) that records
# prompt/theme choices without touching the repo, and the reload marker.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}"
    export XDG_STATE_HOME="${SANDBOX}/.local/state"
    mkdir -p "${SANDBOX}/.config/zsh"
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
    . "${REPO_ROOT_REAL}/src/lib/prompt.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "dots_local_set creates local.zsh with a guarded export" {
    dots_local_set DOTS_PROMPT p10k

    f="${SANDBOX}/.config/zsh/local.zsh"
    [ -f "${f}" ]
    grep -Fq 'export DOTS_PROMPT="${DOTS_PROMPT:-p10k}"' "${f}"
}

@test "dots_local_set is idempotent and updates in place" {
    dots_local_set DOTS_PROMPT p10k
    dots_local_set DOTS_PROMPT starship
    dots_local_set DOTS_THEME kanagawa_wave

    f="${SANDBOX}/.config/zsh/local.zsh"
    [ "$(grep -c 'DOTS_PROMPT' "${f}")" -eq 1 ]
    grep -Fq 'export DOTS_PROMPT="${DOTS_PROMPT:-starship}"' "${f}"
    grep -Fq 'export DOTS_THEME="${DOTS_THEME:-kanagawa_wave}"' "${f}"
}

@test "dots_local_get reads back persisted values" {
    dots_local_set DOTS_PROMPT p10k

    run dots_local_get DOTS_PROMPT
    [ "${status}" -eq 0 ]
    [ "${output}" = "p10k" ]

    run dots_local_get DOTS_MISSING
    [ "${status}" -ne 0 ]
}

@test "dots_request_reload drops the marker the dots wrapper consumes" {
    dots_request_reload
    [ -f "${XDG_STATE_HOME}/dots/reload-needed" ]
}

@test "prompt_validate accepts supported engines and rejects others" {
    run prompt_validate starship
    [ "${status}" -eq 0 ]
    run prompt_validate p10k
    [ "${status}" -eq 0 ]
    run prompt_validate ohmyposh
    [ "${status}" -ne 0 ]
}

@test "shipped zsh config reads choices from the environment, not fences" {
    zshenv="${REPO_ROOT_REAL}/content/home/.config/zsh/.zshenv"
    promptzsh="${REPO_ROOT_REAL}/content/home/.config/zsh/prompt.zsh"
    p10k="${REPO_ROOT_REAL}/content/home/.config/zsh/p10k.zsh"

    grep -Fq 'local.zsh' "${zshenv}"
    grep -Fq 'DOTS_PROMPT' "${promptzsh}"
    ! grep -Fq 'dots:prompt' "${promptzsh}"
    grep -Fq 'DOTS_THEME' "${p10k}"
    ! grep -Fq 'dots:theme' "${p10k}"
}
