#!/usr/bin/env bats
# tests/update_prompt.bats
# Static guardrails for the gated update wizard.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
UPDATE_SH="${REPO_ROOT}/src/commands/update.sh"

@test "update interactive gate defaults Change theme prompt to No" {
    content="$(cat "${UPDATE_SH}")"

    [[ "${content}" == *'tui_confirm "Change theme?" n'* ]]
    [[ "${content}" == *'[ -z "${_arg_theme}" ] && [ -z "${_arg_flavor}" ]'* ]]
}

@test "update only opens pickers after accepting Change theme" {
    start="$(grep -n 'tui_confirm "Change theme?" n' "${UPDATE_SH}" | cut -d: -f1)"
    block="$(sed -n "${start},$((start + 10))p" "${UPDATE_SH}")"

    [[ "${block}" == *'select_theme'* ]]
    [[ "${block}" == *'select_flavor'* ]]
    [[ "${block}" == *'confirm_apply'* ]]
}
