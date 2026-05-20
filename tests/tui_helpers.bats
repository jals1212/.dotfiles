#!/usr/bin/env bats
# tests/tui_helpers.bats
# bats-core unit tests for lib/tui.sh.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export REPO_ROOT="${SANDBOX}"
    MOCKBIN="${SANDBOX}/bin"
    mkdir -p "${MOCKBIN}"
    export PATH="${MOCKBIN}:${PATH}"

    # shellcheck source=../lib/header.sh
    . "${REPO_ROOT_REAL}/lib/header.sh"
    render_header() {
        printf 'theme=%s subtitle=%s\n' "$1" "$2"
    }
    # shellcheck source=../lib/tui.sh
    . "${REPO_ROOT_REAL}/lib/tui.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "render_command_banner reads manifest theme and flavor" {
    cat > "${REPO_ROOT}/manifest.json" <<'JSON'
{"theme":"catppuccin","flavor":"mocha"}
JSON

    run render_command_banner "Apply"

    [ "${status}" -eq 0 ]
    [ "${output}" = "theme=catppuccin/mocha subtitle=Apply" ]
}

@test "render_command_banner falls back to kanagawa" {
    run render_command_banner "Doctor"

    [ "${status}" -eq 0 ]
    [ "${output}" = "theme=kanagawa subtitle=Doctor" ]
}

@test "log_success invokes gum style with expected flags" {
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
printf '%s\n' "$*" > "${GUM_ARGS_FILE}"
printf 'gum:%s\n' "$*"
SH
    chmod +x "${MOCKBIN}/gum"
    export GUM_ARGS_FILE="${SANDBOX}/gum.args"

    run log_success "Apply complete" "theme=kanagawa/dragon" "manifest=${REPO_ROOT}/manifest.json"

    [ "${status}" -eq 0 ]
    grep -q -- "--border rounded" "${GUM_ARGS_FILE}"
    grep -q -- "--border-foreground 141" "${GUM_ARGS_FILE}"
    grep -q -- "--padding 1 2" "${GUM_ARGS_FILE}"
    grep -q -- "--bold" "${GUM_ARGS_FILE}"
}

@test "log_success title carries elapsed-time suffix" {
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
printf '%s\n' "$*"
SH
    chmod +x "${MOCKBIN}/gum"
    TUI_START_EPOCH="$(($(date +%s) - 3))"
    export TUI_START_EPOCH

    run log_success "Apply complete"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ Apply\ complete\ ·\ [0-9]+s ]]
}
