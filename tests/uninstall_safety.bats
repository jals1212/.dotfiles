#!/usr/bin/env bats
# tests/uninstall_safety.bats
# Verifies uninstall removes only declared Dotbot destinations.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    MINI_REPO="${SANDBOX}/repo"

    mkdir -p "${HOME}" "${MINI_REPO}/src" "${MINI_REPO}/config" "${MINI_REPO}/content/themes" "${MINI_REPO}/vendor/dotbot/lib/pyyaml"
    cp -R "${REPO_ROOT_REAL}/src/lib" "${MINI_REPO}/src/lib"
    cp -R "${REPO_ROOT_REAL}/vendor/dotbot/lib/pyyaml/lib" "${MINI_REPO}/vendor/dotbot/lib/pyyaml/lib"
    mkdir -p "${MINI_REPO}/src/commands"
    cp "${REPO_ROOT_REAL}/src/commands/uninstall.sh" "${MINI_REPO}/src/commands/uninstall.sh"
    cp "${REPO_ROOT_REAL}/config/install.conf.yaml" "${MINI_REPO}/config/install.conf.yaml"
    cp "${REPO_ROOT_REAL}/content/themes/kanagawa-dragon.yaml" "${MINI_REPO}/content/themes/kanagawa-dragon.yaml"

    mkdir -p \
        "${MINI_REPO}/content/home/.config/mise" \
        "${MINI_REPO}/content/home/.config/nvim/lua" \
        "${MINI_REPO}/content/assets/palettes/nvim" \
        "${HOME}/.config/nvim" \
        "${HOME}/.local/state/mise/tracked-configs"

    : > "${MINI_REPO}/content/home/.zshrc"
    : > "${MINI_REPO}/content/home/.config/mise/config.toml"
    : > "${MINI_REPO}/content/assets/palettes/nvim/kanagawa-dragon.lua"
    ln -s "${MINI_REPO}/content/assets/palettes/nvim/kanagawa-dragon.lua" \
        "${MINI_REPO}/content/home/.config/nvim/lua/dots-theme.lua"

    ln -s "${MINI_REPO}/content/home/.zshrc" "${HOME}/.zshrc"
    ln -s "${MINI_REPO}/content/home/.config/nvim/lua" "${HOME}/.config/nvim/lua"
    ln -s "${MINI_REPO}/content/home/.config/mise/config.toml" \
        "${HOME}/.local/state/mise/tracked-configs/example"
    printf '{"version":"3.0.0","theme":"kanagawa","flavor":"dragon","applied_at":"now"}\n' \
        > "${MINI_REPO}/manifest.json"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "uninstall removes only declared symlink destinations" {
    run sh "${MINI_REPO}/src/commands/uninstall.sh" --yes

    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.zshrc" ]
    [ ! -e "${HOME}/.config/nvim/lua" ]
    [ -L "${HOME}/.local/state/mise/tracked-configs/example" ]
    [ -L "${MINI_REPO}/content/home/.config/nvim/lua/dots-theme.lua" ]
    [ ! -e "${MINI_REPO}/manifest.json" ]
}

@test "uninstall dry-run preserves declared symlinks and manifest" {
    run sh "${MINI_REPO}/src/commands/uninstall.sh" --dry-run

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Uninstall (dry-run)"* ]]
    [ -L "${HOME}/.zshrc" ]
    [ -L "${HOME}/.config/nvim/lua" ]
    [ -L "${HOME}/.local/state/mise/tracked-configs/example" ]
    [ -f "${MINI_REPO}/manifest.json" ]
}
