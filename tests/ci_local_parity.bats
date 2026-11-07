#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/ci_local_parity.bats
# Keeps ci-local.config.sh (`pnpm exec ci-local`, the CI workflow run on this
# machine) equal to .github/workflows/ci.yml, through the package's parity API
# (tests/ci_local_parity.mjs). Needs `pnpm install` for node_modules; the GitHub
# workflow does not run it (it would spend Actions minutes on Node for a repo
# with no JS), so there the tests skip and the check is local.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
PARITY="${REPO_ROOT_REAL}/tests/ci_local_parity.mjs"

setup() {
    if [ ! -d "${REPO_ROOT_REAL}/node_modules/@jals1212/ci-local" ]; then
        skip "ci-local is not installed: run 'pnpm install' to check the local CI parity"
    fi
    if ! command -v node >/dev/null 2>&1; then
        skip "node not found: ci-local's parity check needs the Node of .nvmrc"
    fi
    SANDBOX="$(mktemp -d)"
}

teardown() {
    [ -z "${SANDBOX:-}" ] || rm -rf "${SANDBOX}"
}

# _sandbox — a copy of what ci-local reads (config, workflow, .nvmrc, runner
# Dockerfile) so a test can change one without touching the repo.
_sandbox() {
    mkdir -p "${SANDBOX}/.github/workflows" "${SANDBOX}/docker/ci-local"
    cp "${REPO_ROOT_REAL}/ci-local.config.sh" "${REPO_ROOT_REAL}/.nvmrc" "${SANDBOX}/"
    cp "${REPO_ROOT_REAL}/.github/workflows/ci.yml" "${SANDBOX}/.github/workflows/ci.yml"
    cp "${REPO_ROOT_REAL}/docker/ci-local/Dockerfile" "${SANDBOX}/docker/ci-local/Dockerfile"
}

@test "the project is dotfiles-ci and the plan mirrors the workflow" {
    run --separate-stderr node "${PARITY}"
    [ "${status}" -eq 0 ]
    [ "${output}" = "ci-local parity ok: project dotfiles-ci, jobs check" ]
    [ -z "${stderr}" ]
}

@test "the plan runs the workflow's two make targets, in order, in one job" {
    cd "${REPO_ROOT_REAL}"
    run --separate-stderr node_modules/.bin/ci-local --list
    [ "${status}" -eq 0 ]
    [ "${lines[2]}" = " 3. [box] shellcheck" ]
    [ "${lines[3]}" = " 4. [box] bats" ]
}

@test "a changed workflow command is a parity problem" {
    _sandbox
    sed -i.bak 's|make -f config/Makefile lint|make -f config/Makefile lint --keep-going|' \
        "${SANDBOX}/.github/workflows/ci.yml"
    run --separate-stderr node "${PARITY}" "${SANDBOX}"
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
    [ "${stderr}" = 'check: "shellcheck" is not in the plan (nor named with ci_not_mirrored)' ]
}

@test "a project name other than dotfiles-ci is reported" {
    _sandbox
    sed -i.bak 's|^CI_PROJECT=dotfiles-ci|CI_PROJECT=dotfiles-other|' "${SANDBOX}/ci-local.config.sh"
    run --separate-stderr node "${PARITY}" "${SANDBOX}"
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *'plan.project is "dotfiles-other", expected "dotfiles-ci"'* ]]
}

@test "package.json declares the MIT license like LICENSE" {
    run grep -q '"license": "MIT"' "${BATS_TEST_DIRNAME}/../package.json"
    [ "${status}" -eq 0 ]
    run grep -q '^MIT License$' "${BATS_TEST_DIRNAME}/../LICENSE"
    [ "${status}" -eq 0 ]
}
