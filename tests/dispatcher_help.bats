#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/dispatcher_help.bats
# ./dots help goes to stdout (exit 0); an unknown command errors on stderr (exit 2).

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "dots help, -h and --help write the usage to stdout and exit 0" {
    for arg in help -h --help; do
        run --separate-stderr sh "${REPO_ROOT}/dots" "${arg}"

        [ "${status}" -eq 0 ]
        [[ "${output}" == "dots - dotfiles manager"* ]]
        [[ "${output}" == *"SUBCOMMANDS"* ]]
        [ -z "${stderr}" ]
    done
}

@test "dots with an unknown command prints the error and usage to stderr and exits 2" {
    run --separate-stderr sh "${REPO_ROOT}/dots" bogus

    [ "${status}" -eq 2 ]
    [ -z "${output}" ]
    [[ "${stderr}" == *"Unknown command: bogus"* ]]
    [[ "${stderr}" == *"dots - dotfiles manager"* ]]
}
