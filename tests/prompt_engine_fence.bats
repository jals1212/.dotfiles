#!/usr/bin/env bats
# tests/prompt_engine_fence.bats
# Verifies the dots:prompt fence rewrite that switches the active prompt engine.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
    . "${REPO_ROOT_REAL}/src/lib/prompt.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "_pr_apply_fence rewrites the active engine in the shipped config" {
    f="${SANDBOX}/prompt.zsh"
    cp "${REPO_ROOT_REAL}/content/home/.config/zsh/prompt.zsh" "${f}"

    run _pr_apply_fence "${f}" '_dots_prompt_engine="starship"'
    [ "${status}" -eq 0 ]
    grep -Fq '_dots_prompt_engine="starship"' "${f}"

    [ "$(grep -c '# >>> dots:prompt >>>' "${f}")" -eq 1 ]
    [ "$(grep -c '# <<< dots:prompt <<<' "${f}")" -eq 1 ]
}

@test "_pr_apply_fence refuses files without exactly one fence" {
    f="${SANDBOX}/no-fence.zsh"
    printf 'eval "$(starship init zsh)"\n' > "${f}"

    run _pr_apply_fence "${f}" '_dots_prompt_engine="p10k"'
    [ "${status}" -ne 0 ]
    ! grep -Fq '_dots_prompt_engine' "${f}"
}

@test "prompt_validate accepts supported engines and rejects others" {
    run prompt_validate starship
    [ "${status}" -eq 0 ]
    run prompt_validate p10k
    [ "${status}" -eq 0 ]
    run prompt_validate ohmyposh
    [ "${status}" -ne 0 ]
}

@test "shipped prompt.zsh carries a dots:prompt fence with an engine line" {
    f="${REPO_ROOT_REAL}/content/home/.config/zsh/prompt.zsh"
    [ "$(grep -c '# >>> dots:prompt >>>' "${f}")" -eq 1 ]
    [ "$(grep -c '# <<< dots:prompt <<<' "${f}")" -eq 1 ]
    grep -q '^_dots_prompt_engine="' "${f}"
}
