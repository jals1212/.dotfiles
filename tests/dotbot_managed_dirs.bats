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
    [[ "${output}" != *"oh-my-posh"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/zoxide"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/mise"* ]]
    [[ "${output}" == *"${HOME}/.config/zsh/plugins/atuin"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim"* ]]
    [[ "${output}" == *"${HOME}/.config/ghostty/themes"* ]]
    [[ "${output}" == *"${HOME}/.config/bat/themes"* ]]
    [[ "${output}" != *"content/assets"* ]]
}

@test "base dotbot config declares zsh fragment and plugin symlinks" {
    config="${REPO_ROOT_REAL}/config/install.conf.yaml"

    grep -Fq "~/.config/zsh/abbr.zsh: content/home/.config/zsh/abbr.zsh" "${config}"
    grep -Fq "~/.config/zsh/paths.zsh: content/home/.config/zsh/paths.zsh" "${config}"
    grep -Fq "~/.config/zsh/plugins/zoxide/zoxide.plugin.zsh: content/home/.config/zsh/plugins/zoxide/zoxide.plugin.zsh" "${config}"
    grep -Fq "~/.config/zsh/plugins/mise/mise.plugin.zsh: content/home/.config/zsh/plugins/mise/mise.plugin.zsh" "${config}"
    grep -Fq "~/.config/zsh/plugins/atuin/atuin.plugin.zsh: content/home/.config/zsh/plugins/atuin/atuin.plugin.zsh" "${config}"
    ! grep -Fq "oh-my-posh" "${config}"
}

@test "base dotbot config glob-links nvim direct children" {
    config="${REPO_ROOT_REAL}/config/install.conf.yaml"

    grep -Fq "~/.config/nvim:" "${config}"
    grep -Fq "path: content/home/.config/nvim/*" "${config}"
    grep -Fq "~/.config/nvim/:" "${config}"
    grep -Fq "path: content/home/.config/nvim/.*" "${config}"
    ! grep -Fq "~/.config/nvim/init.lua: content/home/.config/nvim/init.lua" "${config}"
    ! grep -Fq "~/.config/nvim/lazyvim.json: content/home/.config/nvim/lazyvim.json" "${config}"
}

@test "dotbot_managed_links lists declared destinations only" {
    run dotbot_managed_links

    [ "${status}" -eq 0 ]
    [[ "${output}" == *"${HOME}/.zshrc"* ]]
    [[ "${output}" == *"${HOME}/.config/mise/config.toml"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/.gitignore"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/.neoconf.json"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/init.lua"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/lazy-lock.json"* ]]
    [[ "${output}" == *"${HOME}/.config/nvim/lua"* ]]
    [[ "${output}" != *"${HOME}/.local/state/mise/tracked-configs"* ]]
    [[ "${output}" != *"${HOME}/.config/nvim/lua/dots-theme.lua"* ]]
}

@test "theme configs do not declare mutable nvim dots-theme symlink" {
    if grep -R "~/.config/nvim/lua/dots-theme.lua" "${REPO_ROOT_REAL}/content/themes"; then
        return 1
    fi
}

@test "Brewfile manages starship and not oh-my-posh" {
    brewfile="${REPO_ROOT_REAL}/config/Brewfile"

    grep -Fq 'brew "starship"' "${brewfile}"
    ! grep -Fq "oh-my-posh" "${brewfile}"
}

@test "theme configs do not declare starship (base link, fence-switched)" {
    for f in "${REPO_ROOT_REAL}"/content/themes/*-*.yaml; do
        ! grep -Fq "starship" "${f}"
        ! grep -Fq "oh-my-posh" "${f}"
    done
}

@test "base dotbot config links starship.toml as a base file" {
    config="${REPO_ROOT_REAL}/config/install.conf.yaml"

    grep -Fq "~/.config/starship.toml: content/home/.config/starship.toml" "${config}"
}

@test "starship.toml carries a dots:theme fence and per-theme palettes" {
    conf="${REPO_ROOT_REAL}/content/home/.config/starship.toml"

    grep -Fq "# >>> dots:theme >>>" "${conf}"
    grep -Fq "# <<< dots:theme <<<" "${conf}"
    grep -Eq '^palette = ' "${conf}"
    grep -Fq "[palettes.kanagawa_dragon]" "${conf}"
    grep -Fq "[palettes.catppuccin_mocha]" "${conf}"
}
