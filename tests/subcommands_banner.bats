#!/usr/bin/env bats
# tests/subcommands_banner.bats
# Ensures dispatcher subcommands render banners only when not launched from main menu.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "subcommands source lib/tui.sh and call render_subcommand_banner" {
    for script in update theme doctor clean upgrade uninstall; do
        file="${REPO_ROOT}/src/commands/${script}.sh"
        content="$(cat "${file}")"
        [[ "${content}" == *"lib/tui.sh"* ]]
        [[ "${content}" == *"render_subcommand_banner"* ]]
    done
}

# --- compact one-line header (S4) ------------------------------------------

_doctor_sandbox() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    REPO="${SANDBOX}/repo"
    mkdir -p "${HOME}" "${REPO}/vendor/dotbot/bin"
    cp -R "${REPO_ROOT}/src" "${REPO}/src"
    cp "${REPO_ROOT}/dots" "${REPO}/dots"
    printf '#!/bin/sh\nexit 0\n' > "${REPO}/vendor/dotbot/bin/dotbot"
    chmod +x "${REPO}/vendor/dotbot/bin/dotbot"
    printf '%s\n' 'DOCTOR_CHECKS="check_dotbot_submodule"' 'export DOCTOR_CHECKS' >> "${REPO}/src/lib/doctor.sh"
    printf '{"theme":"catppuccin","flavor":"mocha","prompt":"starship"}\n' > "${REPO}/manifest.json"
    export NO_COLOR=1
}

@test "dots doctor starts with the one-line header instead of the ASCII logo" {
    _doctor_sandbox
    run env -u DOTS_MENU_DISPATCH sh "${REPO}/dots" doctor
    rm -rf "${SANDBOX}"
    echo "${output}"

    [ "${status}" -eq 0 ]
    [ "$(printf '%s\n' "${output}" | sed -n 1p)" = "jals1212 DOTS · Doctor · catppuccin/mocha · starship" ]
    [[ "${output}" != *"██"* ]]
}

@test "dots doctor under the menu dispatch prints no header" {
    _doctor_sandbox
    run env DOTS_MENU_DISPATCH=1 sh "${REPO}/dots" doctor
    rm -rf "${SANDBOX}"

    [ "${status}" -eq 0 ]
    [[ "${output}" != *"jals1212 DOTS"* ]]
}

@test "the 12-line ASCII header is gone; the color map stays" {
    ! grep -rq 'render_header' "${REPO_ROOT}/src" "${REPO_ROOT}/dots"
    ! grep -q '██' "${REPO_ROOT}/src/lib/header.sh"
    grep -q '_header_color_code()' "${REPO_ROOT}/src/lib/header.sh"
}
