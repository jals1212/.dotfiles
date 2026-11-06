#!/usr/bin/env bats
# tests/no_gum.bats
# Guard: gum was removed from ./dots and the install; keep it out.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "no reference to gum in src, dots, config or content" {
    cd "${REPO_ROOT_REAL}"
    run grep -rnw gum src dots config content
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
}
