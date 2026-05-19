#!/usr/bin/env bats
# tests/manifest.bats
# bats-core unit tests for manifest_write and manifest_read_field in lib/manifest.sh.
# Requires: bats-core, jq.
# Run: bats tests/manifest.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # shellcheck source=../lib/log.sh
    . "${REPO_ROOT}/lib/log.sh"
    # shellcheck source=../lib/detect.sh
    . "${REPO_ROOT}/lib/detect.sh"
    # shellcheck source=../lib/manifest.sh
    . "${REPO_ROOT}/lib/manifest.sh"

    SANDBOX="$(mktemp -d)"
    MANIFEST_PATH="${SANDBOX}/manifest.json"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "manifest_write produces valid JSON with version 2.0.0" {
    manifest_write "${MANIFEST_PATH}" kanagawa dragon mauve \
        "zsh,tmux,nvim" "abc123deadbeef"

    [ -f "${MANIFEST_PATH}" ]
    version="$(jq -r .version "${MANIFEST_PATH}")"
    [ "${version}" = "2.0.0" ]
}

@test "manifest_read_field round-trips theme and flavor" {
    manifest_write "${MANIFEST_PATH}" catppuccin mocha mauve \
        "zsh,nvim" "deadbeef"

    theme="$(manifest_read_field "${MANIFEST_PATH}" theme)"
    flavor="$(manifest_read_field "${MANIFEST_PATH}" flavor)"

    [ "${theme}" = "catppuccin" ]
    [ "${flavor}" = "mocha" ]
}

@test "manifest_read_field returns empty for absent file" {
    result="$(manifest_read_field "/nonexistent/manifest.json" theme)"
    [ -z "${result}" ]
}
