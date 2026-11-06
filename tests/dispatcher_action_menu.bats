#!/usr/bin/env bats
# tests/dispatcher_action_menu.bats
# bats-core tests for no-args dispatcher action menu loop.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    TEST_HOME="${SANDBOX}/home"
    mkdir -p "${TEST_HOME}" "${TEST_HOME}/.config" "${TEST_HOME}/.cache"
    export HOME="${TEST_HOME}"
    export XDG_CONFIG_HOME="${TEST_HOME}/.config"
    export XDG_CACHE_HOME="${TEST_HOME}/.cache"
    REPO_COPY="${SANDBOX}/repo"
    mkdir -p "${REPO_COPY}"
    tar -C "${REPO_ROOT}" \
        --exclude='.git' \
        --exclude='.backups' \
        --exclude='.grit' \
        --exclude='.opencode' \
        --exclude='tmp' \
        --exclude='orchestra' \
        --exclude='vendor' \
        -cf - . | tar -C "${REPO_COPY}" -xf -
    cat > "${REPO_COPY}/manifest.json" <<'JSON'
{"version":"3.0.0","theme":"kanagawa","flavor":"dragon","applied_at":"2026-01-01T00:00:00Z"}
JSON
    MOCKBIN="${SANDBOX}/bin"
    mkdir -p "${MOCKBIN}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _keys <printf-format> — write menu keys to a file and print its path.
_keys() {
    printf "$1" > "${SANDBOX}/keys"
    printf '%s' "${SANDBOX}/keys"
}

_require_bsd_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

@test "interactive no-args draws the action menu and q quits" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        DOTS_MENU_INPUT="$(_keys 'q')" \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"jals1212 DOTS"*"· kanagawa/dragon"* ]]
    [[ "${output}" == *"update"*"upgrade"*"clean"*"doctor"*"theme"*"prompt"*"uninstall"*"help"*"quit"* ]]
    [[ "${output}" == *"q quit"* ]]
}

@test "initialized non-TTY no-args errors and exits 2" {
    run "${REPO_COPY}/dots"

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"non-interactive './dots' requires a subcommand"* ]]
}

@test "missing manifest no-args dispatches update automatically" {
    rm -f "${REPO_COPY}/manifest.json"

    run "${REPO_COPY}/dots"

    # The sandbox copy intentionally excludes .git/vendor, so the auto-update
    # path is expected to reach update and then fail during submodule preflight.
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Update"* ]]
    [[ "${output}" == *"Base dotbot apply failed"* ]]
}

@test "help menu choice prints usage and loops back, then quits" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    # Keys: move to help (8th item), enter (loops back), then q (exits).
    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        DOTS_MENU_INPUT="$(_keys 'jjjjjjj\nq')" \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"dots - dotfiles manager"* ]]
}

@test "quit menu choice exits 0 and runs no subcommand" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        DOTS_MENU_INPUT="$(_keys 'jjjjjjjj\n')" \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Update complete"* ]]
    [[ "${output}" != *"Sync complete"* ]]
}

@test "second menu render pre-selects last action" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    # Pick help (enter), then enter again on the pre-selected help, then q.
    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        DOTS_MENU_INPUT="$(_keys 'jjjjjjj\n\nq')" \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [ "$(printf '%s' "${output}" | grep -c 'dots - dotfiles manager')" -eq 2 ]
}
