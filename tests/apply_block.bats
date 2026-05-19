#!/usr/bin/env bats
# tests/apply_block.bats
# bats-core unit tests for apply_block in lib/deploy.sh.
# Requires: bats-core, awk.
# Run: bats tests/apply_block.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # shellcheck source=../lib/log.sh
    . "${REPO_ROOT}/lib/log.sh"
    # shellcheck source=../lib/detect.sh
    . "${REPO_ROOT}/lib/detect.sh"
    # shellcheck source=../lib/deploy.sh
    . "${REPO_ROOT}/lib/deploy.sh"

    SANDBOX="$(mktemp -d)"
    TARGET="${SANDBOX}/target.txt"
    printf 'existing content\n' > "${TARGET}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "apply_block inserts sentinels when absent" {
    apply_block "${TARGET}" "bat-theme" 'export BAT_THEME="kanagawa"'

    grep -qF '# dots:bat-theme begin' "${TARGET}"
    grep -qF 'export BAT_THEME="kanagawa"' "${TARGET}"
    grep -qF '# dots:bat-theme end' "${TARGET}"
}

@test "apply_block is idempotent on second run" {
    apply_block "${TARGET}" "bat-theme" 'export BAT_THEME="kanagawa"'
    content_first="$(cat "${TARGET}")"

    apply_block "${TARGET}" "bat-theme" 'export BAT_THEME="kanagawa"'
    content_second="$(cat "${TARGET}")"

    [ "${content_first}" = "${content_second}" ]
}

@test "apply_block replaces content when changed" {
    apply_block "${TARGET}" "bat-theme" 'export BAT_THEME="kanagawa"'
    apply_block "${TARGET}" "bat-theme" 'export BAT_THEME="catppuccin"'

    grep -qF 'export BAT_THEME="catppuccin"' "${TARGET}"
    # Old value must be gone
    run grep -cF 'export BAT_THEME="kanagawa"' "${TARGET}"
    [ "${output}" = "0" ]
}
