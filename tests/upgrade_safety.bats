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
    [[ "${output}" == *"skipping brew cleanup"* ]] || return 1
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
    [[ "${output}" == *"is destructive; rerun with --yes"* ]] || return 1
    run ! grep -q -- '--force' "${CALLS}"
    run ! grep -q 'mise prune' "${CALLS}"
}

@test "upgrade cleanup and prune require explicit yes to apply" {
    run sh "${REPO_COPY}/dots" upgrade --cleanup --prune --yes

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --force' "${CALLS}"
    grep -q 'mise prune --yes' "${CALLS}"
}

# BSD/macOS `script -q /dev/null cmd` syntax; util-linux script differs.
_require_bsd_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

# _tty_upgrade <keys> <args...> — run ./dots upgrade on a PTY, keys on fd 3.
_tty_upgrade() {
    printf "$1" > "${SANDBOX}/keys"
    shift
    run script -q /dev/null sh -c 'k="$1"; shift; exec 3<"$k"; sh "$@"' _ "${SANDBOX}/keys" "${REPO_COPY}/dots" upgrade "$@"
}

@test "upgrade cleanup on a TTY stays non-destructive when the answer is n, esc or enter" {
    _require_bsd_script || skip "PTY script syntax unavailable"
    for keys in 'n' '\033' '\n'; do
        _tty_upgrade "${keys}" --cleanup --prune
        [ "${status}" -eq 0 ]
        run ! grep -q -- '--force' "${CALLS}"
        run ! grep -q 'mise prune' "${CALLS}"
    done
}

@test "upgrade cleanup on a TTY applies after y" {
    _require_bsd_script || skip "PTY script syntax unavailable"
    _tty_upgrade 'yy' --cleanup --prune

    [ "${status}" -eq 0 ]
    grep -q 'brew bundle cleanup --force' "${CALLS}"
    grep -q 'mise prune --yes' "${CALLS}"
}

# --- upgrade --commit commits only what it advanced -------------------------

# _git_sandbox — a git repo in ${SANDBOX}/super with the three vendored
# submodules backed by local upstream repos, a copy of src/ and dots, and an
# unrelated staged file.
_git_sandbox() {
    export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
    export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0=protocol.file.allow GIT_CONFIG_VALUE_0=always
    SUPER="${SANDBOX}/super"
    mkdir -p "${SUPER}"
    git -C "${SUPER}" init -q -b main
    cp -R "${REPO_ROOT}/src" "${SUPER}/src"
    cp "${REPO_ROOT}/dots" "${SUPER}/dots"
    for sub in vendor/dotbot vendor/plugins/dotbot-brew vendor/plugins/dotbot-mise; do
        up="${SANDBOX}/upstream/$(basename "${sub}")"
        mkdir -p "${up}"
        git -C "${up}" init -q -b main
        echo one > "${up}/f"
        git -C "${up}" add f
        git -C "${up}" commit -q -m one
        mkdir -p "$(dirname "${SUPER}/${sub}")"
        git -C "${SUPER}" submodule add -q "${up}" "${sub}" 2>/dev/null
    done
    git -C "${SUPER}" add -A
    git -C "${SUPER}" commit -q -m base
    # Upstream advances: only dotbot-brew gets a new commit.
    up="${SANDBOX}/upstream/dotbot-brew"
    echo two > "${up}/f"
    git -C "${up}" commit -q -am two
    # Unrelated staged change.
    echo staged > "${SUPER}/unrelated.txt"
    git -C "${SUPER}" add unrelated.txt
}

@test "upgrade --commit commits only the advanced gitlinks and leaves other staged files staged" {
    _git_sandbox

    run sh "${SUPER}/dots" upgrade --commit
    echo "${output}"

    [ "${status}" -eq 0 ]
    [ "$(git -C "${SUPER}" rev-list --count HEAD)" -eq 2 ]
    [ "$(git -C "${SUPER}" show --name-only --pretty=format: HEAD)" = "vendor/plugins/dotbot-brew" ]
    [ "$(git -C "${SUPER}" diff --cached --name-only)" = "unrelated.txt" ]
}

@test "upgrade --commit without an advanced submodule creates no commit" {
    _git_sandbox
    up="${SANDBOX}/upstream/dotbot-brew"
    git -C "${SUPER}" submodule update --remote -q vendor/plugins/dotbot-brew
    git -C "${SUPER}" commit -q -m advance vendor/plugins/dotbot-brew
    before="$(git -C "${SUPER}" rev-parse HEAD)"

    run sh "${SUPER}/dots" upgrade --commit

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"no submodule advanced; no commit created"* ]] || return 1
    [ "$(git -C "${SUPER}" rev-parse HEAD)" = "${before}" ]
    [ "$(git -C "${SUPER}" diff --cached --name-only)" = "unrelated.txt" ]
}
