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
        "${MINI_REPO}/content/home/.config/zsh" \
        "${MINI_REPO}/content/home/.config/mise" \
        "${MINI_REPO}/content/home/.config/nvim/lua" \
        "${MINI_REPO}/content/assets/palettes/nvim" \
        "${HOME}/.config/zsh" \
        "${HOME}/.config/nvim" \
        "${HOME}/.local/state/mise/tracked-configs"

    : > "${MINI_REPO}/content/home/.config/zsh/.zshrc"
    : > "${MINI_REPO}/content/home/.config/mise/config.toml"
    : > "${MINI_REPO}/content/assets/palettes/nvim/kanagawa-dragon.lua"
    ln -s "${MINI_REPO}/content/assets/palettes/nvim/kanagawa-dragon.lua" \
        "${MINI_REPO}/content/home/.config/nvim/lua/dots-theme.lua"

    ln -s "${MINI_REPO}/content/home/.config/zsh/.zshrc" "${HOME}/.config/zsh/.zshrc"
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
    [ ! -e "${HOME}/.config/zsh/.zshrc" ]
    [ ! -e "${HOME}/.config/nvim/lua" ]
    [ -L "${HOME}/.local/state/mise/tracked-configs/example" ]
    [ -L "${MINI_REPO}/content/home/.config/nvim/lua/dots-theme.lua" ]
    [ ! -e "${MINI_REPO}/manifest.json" ]
}

@test "uninstall dry-run preserves declared symlinks and manifest" {
    run sh "${MINI_REPO}/src/commands/uninstall.sh" --dry-run

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"Uninstall (dry-run)"* ]]
    [ -L "${HOME}/.config/zsh/.zshrc" ]
    [ -L "${HOME}/.config/nvim/lua" ]
    [ -L "${HOME}/.local/state/mise/tracked-configs/example" ]
    [ -f "${MINI_REPO}/manifest.json" ]
}

# BSD/macOS `script -q /dev/null cmd` syntax; util-linux script differs.
_require_bsd_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

# _tty_uninstall <keys> — run uninstall on a PTY with <keys> on fd 3.
_tty_uninstall() {
    printf "$1" > "${SANDBOX}/keys"
    run script -q /dev/null sh -c 'exec 3<"$1"; sh "$2"' _ "${SANDBOX}/keys" "${MINI_REPO}/src/commands/uninstall.sh"
}

@test "uninstall on a TTY keeps everything when the answer is n" {
    _require_bsd_script || skip "PTY script syntax unavailable"
    _tty_uninstall 'n'

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"uninstall aborted"* ]]
    [ -L "${HOME}/.config/zsh/.zshrc" ]
    [ -L "${HOME}/.config/nvim/lua" ]
    [ -f "${MINI_REPO}/manifest.json" ]
}

@test "uninstall on a TTY keeps everything on esc, enter or end of input" {
    _require_bsd_script || skip "PTY script syntax unavailable"
    for keys in '\033' '\n' ''; do
        _tty_uninstall "${keys}"
        [ "${status}" -eq 0 ]
        [[ "${output}" == *"uninstall aborted"* ]]
        [ -L "${HOME}/.config/zsh/.zshrc" ]
        [ -f "${MINI_REPO}/manifest.json" ]
    done
}

@test "uninstall on a TTY removes the declared symlinks when the answer is y" {
    _require_bsd_script || skip "PTY script syntax unavailable"
    _tty_uninstall 'y'

    [ "${status}" -eq 0 ]
    [ ! -e "${HOME}/.config/zsh/.zshrc" ]
    [ ! -e "${MINI_REPO}/manifest.json" ]
}
