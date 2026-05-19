#!/usr/bin/env bats
# tests/backup_create.bats
# bats-core unit tests for backup_create and backup_latest in lib/backup.sh.
# Requires: bats-core.
# Run: bats tests/backup_create.bats

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    # shellcheck source=../lib/log.sh
    . "${REPO_ROOT}/lib/log.sh"
    # shellcheck source=../lib/backup.sh
    . "${REPO_ROOT}/lib/backup.sh"

    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}/.config/zsh"
    printf 'zshrc content\n' > "${HOME}/.config/zsh/.zshrc"

    REPO_SANDBOX="${SANDBOX}/repo"
    mkdir -p "${REPO_SANDBOX}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "backup_create produces a timestamped backup directory" {
    backup_create "${REPO_SANDBOX}"

    backup_count="$(find "${REPO_SANDBOX}/.backups" -mindepth 1 -maxdepth 1 -type d | wc -l | tr -d ' ')"
    [ "${backup_count}" -ge 1 ]
}

@test "backup_create copies managed files into backup" {
    backup_create "${REPO_SANDBOX}"

    # .zshrc should be somewhere under .backups
    found="$(find "${REPO_SANDBOX}/.backups" -name '.zshrc' | wc -l | tr -d ' ')"
    [ "${found}" -ge 1 ]
}

@test "backup_latest returns the most recent backup" {
    backup_create "${REPO_SANDBOX}"
    latest="$(backup_latest "${REPO_SANDBOX}")"

    [ -n "${latest}" ]
    [ -d "${latest}" ]
}
