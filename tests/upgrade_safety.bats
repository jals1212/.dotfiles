#!/usr/bin/env bats
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
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
printf 'gum %s\n' "$*" >> "${CALLS}"
if [ "$1" = "style" ]; then
    printf '%s\n' "$*"
    exit 0
fi
exit 1
SH
    chmod +x "${MOCKBIN}/brew" "${MOCKBIN}/mise" "${MOCKBIN}/gum"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "upgrade default skips brew cleanup entirely and skips mise prune" {
    run sh "${REPO_COPY}/dots" upgrade

    [ "${status}" -eq 0 ]
    ! grep -q 'brew bundle cleanup' "${CALLS}"
    ! grep -q 'mise prune' "${CALLS}"
    [[ "${output}" == *"skipping brew cleanup"* ]]
}


@test "upgrade cleanup dry-run reports candidates without force" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup --dry-run

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --file=' "${CALLS}"
    ! grep -q -- '--force' "${CALLS}"
    ! grep -q 'mise prune' "${CALLS}"
}

@test "upgrade cleanup without yes remains non-destructive on non-TTY" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup

    [ "${status}" -eq 0 ]
    ! grep -q -- '--force' "${CALLS}"
    ! grep -q 'mise prune' "${CALLS}"
    [[ "${output}" == *"is destructive; rerun with --yes"* ]]
}

@test "upgrade cleanup and prune require explicit yes to apply" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup --prune --yes

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --force' "${CALLS}"
    grep -q 'mise prune --yes' "${CALLS}"
}
