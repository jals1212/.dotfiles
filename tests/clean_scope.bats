#!/usr/bin/env bats
# tests/clean_scope.bats
# Verifies `dots clean` only removes broken symlinks that point into this repo
# and *.dotbot-backup.* files of paths this repo declares (never foreign ones).

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    MINI_REPO="${SANDBOX}/repo"

    mkdir -p "${HOME}" "${MINI_REPO}/src/commands" "${MINI_REPO}/config" \
        "${MINI_REPO}/content/themes" "${MINI_REPO}/content/home/.config/zsh" \
        "${MINI_REPO}/vendor/dotbot/lib/pyyaml" "${HOME}/.config/zsh"
    cp -R "${REPO_ROOT_REAL}/src/lib" "${MINI_REPO}/src/lib"
    cp -R "${REPO_ROOT_REAL}/vendor/dotbot/lib/pyyaml/lib" "${MINI_REPO}/vendor/dotbot/lib/pyyaml/lib"
    cp "${REPO_ROOT_REAL}/src/commands/clean.sh" "${MINI_REPO}/src/commands/clean.sh"
    cp "${REPO_ROOT_REAL}/config/install.conf.yaml" "${MINI_REPO}/config/install.conf.yaml"
    cp "${REPO_ROOT_REAL}/content/themes/kanagawa-dragon.yaml" "${MINI_REPO}/content/themes/kanagawa-dragon.yaml"

    # Declared destinations ~/.zshenv and ~/.config/zsh/.zshrc, sources present.
    : > "${MINI_REPO}/content/home/.zshenv"
    : > "${MINI_REPO}/content/home/.config/zsh/.zshrc"
    ln -s "${MINI_REPO}/content/home/.zshenv" "${HOME}/.zshenv"
    ln -s "${MINI_REPO}/content/home/.config/zsh/.zshrc" "${HOME}/.config/zsh/.zshrc"
}

teardown() {
    rm -rf "${SANDBOX}"
}

_clean() { run sh "${MINI_REPO}/src/commands/clean.sh" "$@"; }

# _has / _lacks <text> — explicit output assertions (a failing [[ ]] does not
# abort a bats test on older bash).
_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1"; return 1; }
_lacks() { case "${output}" in *"$1"*) echo "unexpected: $1"; return 1 ;; esac; return 0; }

# _old <path> — make <path> older than the default 30-day prune age.
_old() { touch -t 202001010000 "$1"; }

@test "clean keeps a broken symlink in HOME that points outside the repo" {
    ln -s /nonexistent/x "${HOME}/foreign-link"
    ln -s "${MINI_REPO}-other/x" "${HOME}/sibling-prefix-link"
    ln -s /nonexistent/y "${HOME}/.config/zsh/foreign-link"

    _clean

    [ "${status}" -eq 0 ]
    [ -L "${HOME}/foreign-link" ]
    [ -L "${HOME}/sibling-prefix-link" ]
    [ -L "${HOME}/.config/zsh/foreign-link" ]
    [ -L "${HOME}/.zshenv" ]
}

@test "clean keeps a dotbot-backup file of a path the repo does not manage" {
    : > "${HOME}/foo.dotbot-backup.20240101"
    : > "${HOME}/.config/zsh/unmanaged.dotbot-backup.20240101-120000"
    _old "${HOME}/foo.dotbot-backup.20240101"
    _old "${HOME}/.config/zsh/unmanaged.dotbot-backup.20240101-120000"

    _clean

    [ "${status}" -eq 0 ]
    [ -f "${HOME}/foo.dotbot-backup.20240101" ]
    [ -f "${HOME}/.config/zsh/unmanaged.dotbot-backup.20240101-120000" ]
}

@test "clean removes a broken symlink that points into the repo" {
    ln -s "${MINI_REPO}/content/home/.removed" "${HOME}/.removed"
    ln -s "${MINI_REPO}/content/home/.config/zsh/gone.zsh" "${HOME}/.config/zsh/gone.zsh"
    ln -s "../repo/content/home/.relative-gone" "${HOME}/.relative-gone"

    _clean

    [ "${status}" -eq 0 ]
    [ ! -L "${HOME}/.removed" ]
    [ ! -L "${HOME}/.config/zsh/gone.zsh" ]
    [ ! -L "${HOME}/.relative-gone" ]
    # Healthy repo links are untouched.
    [ -L "${HOME}/.zshenv" ]
    [ -L "${HOME}/.config/zsh/.zshrc" ]
}

@test "clean removes old dotbot-backup files of declared destinations" {
    : > "${HOME}/.zshenv.dotbot-backup.20240101-120000"
    : > "${HOME}/.config/zsh/.zshrc.dotbot-backup.20240101-120000"
    _old "${HOME}/.zshenv.dotbot-backup.20240101-120000"
    _old "${HOME}/.config/zsh/.zshrc.dotbot-backup.20240101-120000"

    _clean

    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.zshenv.dotbot-backup.20240101-120000" ]
    [ ! -e "${HOME}/.config/zsh/.zshrc.dotbot-backup.20240101-120000" ]
}

@test "clean keeps a recent dotbot-backup of a declared destination" {
    : > "${HOME}/.zshenv.dotbot-backup.20240101-120000"

    _clean

    [ "${status}" -eq 0 ]
    [ -f "${HOME}/.zshenv.dotbot-backup.20240101-120000" ]
}

@test "clean dry-run reports repo-owned removals and removes nothing" {
    ln -s "${MINI_REPO}/content/home/.removed" "${HOME}/.removed"
    ln -s /nonexistent/x "${HOME}/foreign-link"
    : > "${HOME}/.zshenv.dotbot-backup.20240101-120000"
    : > "${HOME}/foo.dotbot-backup.20240101"
    _old "${HOME}/.zshenv.dotbot-backup.20240101-120000"
    _old "${HOME}/foo.dotbot-backup.20240101"

    _clean --dry-run

    [ "${status}" -eq 0 ]
    _has "would-remove: ${HOME}/.removed"
    _has "would-remove: ${HOME}/.zshenv.dotbot-backup.20240101-120000"
    _lacks "foreign-link"
    _lacks "foo.dotbot-backup"
    _has "would remove 1 dead symlink(s) + prune 1 stale backup(s)"
    [ -L "${HOME}/.removed" ]
    [ -L "${HOME}/foreign-link" ]
    [ -f "${HOME}/.zshenv.dotbot-backup.20240101-120000" ]
    [ -f "${HOME}/foo.dotbot-backup.20240101" ]
}

@test "clean keeps non-dotbot backups, dir/symlink backups, link chains and ../ escapes" {
    ln -s "${MINI_REPO}/../x" "${HOME}/dotdot-escape"
    ln -s /nonexistent/x "${HOME}/foreign-target"
    ln -s "${HOME}/foreign-target" "${HOME}/foreign-chain"
    : > "${HOME}/.zshenv.dotbot-backup.old"; _old "${HOME}/.zshenv.dotbot-backup.old"
    mkdir "${HOME}/.zshenv.dotbot-backup.20200101"; _old "${HOME}/.zshenv.dotbot-backup.20200101"
    ln -s /etc/hosts "${HOME}/.zshenv.dotbot-backup.20200102"
    : > "${HOME}/.zshrc.dotbot-backup.20200101"; _old "${HOME}/.zshrc.dotbot-backup.20200101"

    _clean

    [ "${status}" -eq 0 ]
    [ -L "${HOME}/dotdot-escape" ]
    [ -L "${HOME}/foreign-chain" ]
    [ -e "${HOME}/.zshenv.dotbot-backup.old" ]
    [ -d "${HOME}/.zshenv.dotbot-backup.20200101" ]
    [ -L "${HOME}/.zshenv.dotbot-backup.20200102" ]
    [ -e "${HOME}/.zshrc.dotbot-backup.20200101" ]
}

@test "clean removes a relative and a chained dangling link into the repo" {
    ln -s "${MINI_REPO}/gone" "${HOME}/abs-dangling"
    ln -s "${HOME}/abs-dangling" "${HOME}/chain-dangling"
    ln -s "../repo/gone2" "${HOME}/rel-dangling"

    _clean

    [ "${status}" -eq 0 ]
    [ ! -L "${HOME}/abs-dangling" ]
    [ ! -L "${HOME}/chain-dangling" ]
    [ ! -L "${HOME}/rel-dangling" ]
}
