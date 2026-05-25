#!/usr/bin/env bats
# tests/dotbot_managed_dirs.bats
# Verifies Dotbot-managed directory discovery derives from Dotbot configs.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    mkdir -p "${HOME}"
    export REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/dotbot.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "dotbot_managed_dirs derives base and theme destination directories" {
    run dotbot_managed_dirs

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${HOME}"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/oh-my-posh"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/zoxide"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/mise"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/atuin"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/lua"* ]]
    [[ "${output}" == *"${HOME}/.config/ghostty/themes"* ]]
    [[ "${output}" == *"${HOME}/.config/bat/themes"* ]]
    [[ "${output}" != *"content/assets"* ]]
}

@test "base dotbot config declares zsh plugin symlinks" {
    config="${REPO_ROOT_REAL}/config/install.conf.yaml"

    grep -Fq "~/.config/zsh/plugins/oh-my-posh/oh-my-posh.plugin.zsh: content/home/.config/zsh/plugins/oh-my-posh/oh-my-posh.plugin.zsh" "${config}"
    grep -Fq "~/.config/zsh/plugins/zoxide/zoxide.plugin.zsh: content/home/.config/zsh/plugins/zoxide/zoxide.plugin.zsh" "${config}"
    grep -Fq "~/.config/zsh/plugins/mise/mise.plugin.zsh: content/home/.config/zsh/plugins/mise/mise.plugin.zsh" "${config}"
    grep -Fq "~/.config/zsh/plugins/atuin/atuin.plugin.zsh: content/home/.config/zsh/plugins/atuin/atuin.plugin.zsh" "${config}"
}

@test "dotbot_managed_links lists declared destinations only" {
    run dotbot_managed_links

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${HOME}/.zshrc"* ]]
    [[ "${output}" == *"${HOME}/.config/mise/config.toml"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/lua"* ]]
    [[ "${output}" != *"${HOME}/.local/state/mise/tracked-configs"* ]]
    [[ "${output}" != *"${HOME}/.config/nvim/lua/dots-theme.lua"* ]]
}

@test "theme configs do not declare mutable nvim dots-theme symlink" {
    if grep -R "~/.config/nvim/lua/dots-theme.lua" "${REPO_ROOT_REAL}/content/themes"; then
        return 1
    fi
}
