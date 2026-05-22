#!/usr/bin/env bats
# tests/subcommands_banner.bats
# Ensures dispatcher subcommands render banners only when not launched from main menu.

REPO_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

@test "subcommands source lib/tui.sh and call render_subcommand_banner" {
    for script in update sync theme doctor clean upgrade uninstall; do
        file="${REPO_ROOT}/src/commands/${script}.sh"
        content="$(cat "${file}")"
        [[ "${content}" == *"lib/tui.sh"* ]]
        [[ "${content}" == *"render_subcommand_banner"* ]]
    done
}
