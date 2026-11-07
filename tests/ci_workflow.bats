#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/ci_workflow.bats
# Guardrail for the Actions-minutes savings in .github/workflows/ci.yml: the
# skipped paths stay the pinned list and stay unread, nothing runs again on
# `main` after a merge, drafts and superseded runs do not cost minutes, and
# every action is pinned by commit SHA.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
WORKFLOW="${REPO_ROOT_REAL}/.github/workflows/ci.yml"

# Prose and plans no test or script reads. docs/ is deliberately absent.
PINNED_IGNORE="odd/**
README.md
AGENTS.md
CLAUDE.md"

# _ignored — the pull_request.paths-ignore entries, one per line.
_ignored() {
    awk '
        /^  pull_request:/ { in_pr = 1; next }
        in_pr && /^  [a-z_]+:/ { in_pr = 0 }
        in_pr && /^    paths-ignore:/ { in_list = 1; next }
        in_pr && in_list && /^      - / { sub(/^      - /, ""); gsub(/'"'"'/, ""); print; next }
        in_pr && in_list { in_list = 0 }
    ' "${WORKFLOW}"
}

@test "paths-ignore is exactly the pinned list" {
    [ "$(_ignored)" = "${PINNED_IGNORE}" ]
}

@test "paths-ignore never skips a control path" {
    for control in 'docs/**' 'src/**' 'tests/**' 'config/**' 'content/**' 'dots' '.github/**'; do
        if _ignored | grep -Fxq -- "${control}"; then
            echo "skipped control path: ${control}"
            return 1
        fi
    done
}

@test "no script, test or config names a skipped path" {
    cd "${REPO_ROOT_REAL}"
    hits="$(grep -rnE 'odd/|README\.md|AGENTS\.md|CLAUDE\.md' dots src config tests \
        --exclude=ci_workflow.bats || true)"
    if [ -n "${hits}" ]; then
        printf '%s\n' "${hits}"
        return 1
    fi
}

@test "workflow has no push trigger" {
    run ! grep -Eq '^  push:|^on:.*push' "${WORKFLOW}"
    grep -Eq '^  pull_request:' "${WORKFLOW}"
    grep -Eq '^  workflow_dispatch:' "${WORKFLOW}"
}

@test "draft pull requests are skipped and marking ready triggers the run" {
    grep -Fq 'if: ${{ !github.event.pull_request.draft }}' "${WORKFLOW}"
    grep -Eq 'types: \[.*ready_for_review.*\]' "${WORKFLOW}"
}

@test "a newer push cancels the superseded run" {
    grep -Fq 'group: ci-${{ github.ref }}' "${WORKFLOW}"
    grep -Fq 'cancel-in-progress: true' "${WORKFLOW}"
}

@test "every action is pinned by full commit SHA" {
    uses="$(grep -E '^\s*-?\s*uses:' "${WORKFLOW}")"
    [ -n "${uses}" ]
    unpinned="$(printf '%s\n' "${uses}" | grep -vE 'uses: [^@ ]+@[0-9a-f]{40}( |$)' || true)"
    if [ -n "${unpinned}" ]; then
        printf '%s\n' "${unpinned}"
        return 1
    fi
}

@test "the workflow runs the same make targets as local development" {
    grep -Fq 'make -f config/Makefile lint' "${WORKFLOW}"
    grep -Fq 'make -f config/Makefile test' "${WORKFLOW}"
    grep -Fq 'submodules: recursive' "${WORKFLOW}"
}

@test "workflow permissions are exactly contents: read" {
    # The top-level `permissions:` block, as indented `key: value` lines.
    block="$(awk '
        /^permissions:/ { in_p = 1; next }
        in_p && /^[^ #]/ { in_p = 0 }
        in_p && /^[ ]+[^ #]/ { sub(/^[ ]+/, ""); print }
    ' "${WORKFLOW}")"
    [ "$(grep -c '^permissions:' "${WORKFLOW}")" -eq 1 ]
    [ "${block}" = "contents: read" ]
    # No job-level permissions that could widen it.
    [ "$(grep -Ec '^[[:space:]]+permissions:' "${WORKFLOW}")" -eq 0 ]
}

@test "workflow references no secrets" {
    if grep -inE 'secrets' "${WORKFLOW}"; then
        return 1
    fi
}

