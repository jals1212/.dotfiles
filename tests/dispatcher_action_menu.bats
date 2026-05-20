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
        -cf - . | tar -C "${REPO_COPY}" -xf -
    cat > "${REPO_COPY}/manifest.json" <<'JSON'
{"version":"2.0.0","theme":"kanagawa","flavor":"dragon","tools":["zsh","tmux"],"source_hash":"test","applied_at":"2026-01-01T00:00:00Z"}
JSON
    MOCKBIN="${SANDBOX}/bin"
    mkdir -p "${MOCKBIN}"
    # Mock gum:
    #   - appends `$*` to GUM_ARGS_FILE (one line per call)
    #   - if GUM_CHOICES is set (comma-separated), returns the Nth on call N
    #   - otherwise returns GUM_CHOICE (default "quit")
    #   - special choice "__empty" -> exit 130 (cancel)
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
# Collapse embedded newlines (multi-line header arg) so each call = 1 file line.
_flat=$(printf '%s' "$*" | tr '\n' ' ')
printf '%s\n' "${_flat}" >> "${GUM_ARGS_FILE}"
if [ ! -s "${GUM_COUNT_FILE}" ]; then printf '0' > "${GUM_COUNT_FILE}"; fi
_n=$(cat "${GUM_COUNT_FILE}")
_n=$((_n + 1))
printf '%s' "${_n}" > "${GUM_COUNT_FILE}"

if [ -n "${GUM_CHOICES:-}" ]; then
    _choice=$(printf '%s' "${GUM_CHOICES}" | awk -F',' -v n="${_n}" '{print $n}')
    [ -z "${_choice}" ] && _choice="quit"
else
    _choice="${GUM_CHOICE:-quit}"
fi

if [ "${_choice}" = "__empty" ]; then
    exit 130
fi
printf '%s\n' "${_choice}"
SH
    chmod +x "${MOCKBIN}/gum"
    export GUM_ARGS_FILE="${SANDBOX}/gum.args"
    export GUM_COUNT_FILE="${SANDBOX}/gum.count"
    : > "${GUM_ARGS_FILE}"
    : > "${GUM_COUNT_FILE}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

_require_bsd_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

@test "interactive no-args calls gum choose with documented options" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        GUM_ARGS_FILE="${GUM_ARGS_FILE}" \
        GUM_COUNT_FILE="${GUM_COUNT_FILE}" \
        GUM_CHOICE=quit \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    grep -q -- "--header Choose an action" "${GUM_ARGS_FILE}"
    grep -q "update sync backup doctor restore uninstall help quit" "${GUM_ARGS_FILE}"
}

@test "initialized non-TTY no-args errors and exits 2" {
    run "${REPO_COPY}/dots"

    [ "${status}" -eq 2 ]
    [[ "${output}" == *"non-interactive './dots' requires a subcommand"* ]]
}

@test "missing manifest no-args dispatches update automatically" {
    rm -f "${REPO_COPY}/manifest.json"

    run "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Update"* ]]
    [[ "${output}" == *"Non-interactive:"* ]]
}

@test "help menu choice prints usage and loops back, then quits" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    # Sequence: first call returns "help" (loops back), second returns "quit" (exits).
    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        GUM_ARGS_FILE="${GUM_ARGS_FILE}" \
        GUM_COUNT_FILE="${GUM_COUNT_FILE}" \
        GUM_CHOICES="help,quit" \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"dots - dotfiles manager"* ]]
    # gum was called twice (help + quit)
    [ "$(wc -l < "${GUM_ARGS_FILE}" | tr -d ' ')" -ge 2 ]
}

@test "quit menu choice exits 0 and runs no subcommand" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        GUM_ARGS_FILE="${GUM_ARGS_FILE}" \
        GUM_COUNT_FILE="${GUM_COUNT_FILE}" \
        GUM_CHOICE=quit \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    [[ "${output}" != *"Update complete"* ]]
    [[ "${output}" != *"Sync complete"* ]]
}

@test "second menu render pre-selects last action" {
    _require_bsd_script || skip "PTY script syntax unavailable"

    # First call: pick "doctor" (will fail since manifest is dummy; loop continues).
    # Second call: quit. Second gum invocation should include --selected=doctor.
    run script -q /dev/null env \
        PATH="${MOCKBIN}:${PATH}" \
        GUM_ARGS_FILE="${GUM_ARGS_FILE}" \
        GUM_COUNT_FILE="${GUM_COUNT_FILE}" \
        GUM_CHOICES="doctor,quit" \
        DOTS_NO_PAUSE=1 \
        "${REPO_COPY}/dots"

    [ "${status}" -eq 0 ]
    # Second gum call (line 2 of args file) must carry --selected=doctor
    sed -n '2p' "${GUM_ARGS_FILE}" | grep -q -- "--selected=doctor"
}
