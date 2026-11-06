#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/upgrade_safety.bats
# Ensures ./dots upgrade is non-destructive unless explicitly confirmed.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    REPO_COPY="${SANDBOX}/repo"
    mkdir -p "${REPO_COPY}"
    tar -C "${REPO_ROOT}" \
        --exclude='.git' \
        --exclude='.grit' \
        --exclude='.opencode' \
        --exclude='orchestra' \
        --exclude='vendor' \
        -cf - . | tar -C "${REPO_COPY}" -xf -

    MOCKBIN="${SANDBOX}/bin"
    mkdir -p "${MOCKBIN}"
    export PATH="${MOCKBIN}:${PATH}"
    export CALLS="${SANDBOX}/calls.log"
    : > "${CALLS}"

    cat > "${MOCKBIN}/brew" <<'SH'
#!/bin/sh
printf 'brew %s\n' "$*" >> "${CALLS}"
exit 0
SH
    cat > "${MOCKBIN}/mise" <<'SH'
#!/bin/sh
printf 'mise %s\n' "$*" >> "${CALLS}"
exit 0
SH
    chmod +x "${MOCKBIN}/brew" "${MOCKBIN}/mise"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "upgrade default skips brew cleanup entirely and skips mise prune" {
    run sh "${REPO_COPY}/dots" upgrade

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"skipping brew cleanup"* ]]
    run ! grep -q 'brew bundle cleanup' "${CALLS}"
    run ! grep -q 'mise prune' "${CALLS}"
}


@test "upgrade cleanup dry-run reports candidates without force" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup --dry-run

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --file=' "${CALLS}"
    run ! grep -q -- '--force' "${CALLS}"
    run ! grep -q 'mise prune' "${CALLS}"
}

@test "upgrade cleanup without yes remains non-destructive on non-TTY" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"is destructive; rerun with --yes"* ]]
    run ! grep -q -- '--force' "${CALLS}"
    run ! grep -q 'mise prune' "${CALLS}"
}

@test "upgrade cleanup and prune require explicit yes to apply" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup --prune --yes

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --force' "${CALLS}"
    grep -q 'mise prune --yes' "${CALLS}"
}

# _tty_upgrade <keys> <args...> — run ./dots upgrade on a PTY, keys on fd 3.
_tty_upgrade() {
    printf "$1" > "${SANDBOX}/keys"
    shift
    run script -q /dev/null sh -c 'k="$1"; shift; exec 3<"$k"; sh "$@"' _ "${SANDBOX}/keys" "${REPO_COPY}/dots" upgrade "$@"
}

@test "upgrade cleanup on a TTY stays non-destructive when the answer is n, esc or enter" {
    command -v script >/dev/null 2>&1 || skip "script unavailable"
    for keys in 'n' '\033' '\n'; do
        _tty_upgrade "${keys}" --cleanup --prune
        [ "${status}" -eq 0 ]
        run ! grep -q -- '--force' "${CALLS}"
        run ! grep -q 'mise prune' "${CALLS}"
    done
}

@test "upgrade cleanup on a TTY applies after y" {
    command -v script >/dev/null 2>&1 || skip "script unavailable"
    _tty_upgrade 'yy' --cleanup --prune

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --force' "${CALLS}"
    grep -q 'mise prune --yes' "${CALLS}"
}
