#!/usr/bin/env bats
# tests/log_ok.bats
# bats-core unit tests for log_ok in lib/log.sh.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # shellcheck source=../lib/log.sh
    . "${REPO_ROOT}/src/lib/log.sh"
}

@test "log_ok writes plain prefix on non-TTY stderr" {
    run sh -c ". '${REPO_ROOT}/src/lib/log.sh'; log_ok 'Backup written'"

    [ "${status}" -eq 0 ]
    [ "${output}" = "[OK] Backup written" ]
}

@test "log_ok respects NO_COLOR" {
    run sh -c "NO_COLOR=1 . '${REPO_ROOT}/src/lib/log.sh'; log_ok 'Backup written'"

    [ "${status}" -eq 0 ]
    [ "${output}" = "[OK] Backup written" ]
}

@test "log_ok colors prefix with ANSI 76 on TTY stderr" {
    command -v script >/dev/null 2>&1 || skip "script command unavailable"
    script -q /dev/null env true >/dev/null 2>&1 || skip "BSD script syntax unavailable"

    run script -q /dev/null sh -c ". '${REPO_ROOT}/src/lib/log.sh'; log_ok 'Backup written'"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"38;5;76m[OK]"* ]]
    [[ "${output}" == *"Backup written"* ]]
}
