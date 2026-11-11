#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/components_command.bats
# Verifies `./dots components`: the machine-local choice of which terminal
# components (tmux, herdr TUI/core/app, Ghostty) ./dots installs, recorded as
# DOTS_COMPONENTS in ~/.config/zsh/local.zsh. The command only records the
# choice; installing is gated on it elsewhere. Nothing here calls brew or curl.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    export XDG_STATE_HOME="${HOME}/.local/state"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin"
    export NO_COLOR=1
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    CMD="${REPO_ROOT_REAL}/src/commands/components.sh"
    TOOL_LOG="${SANDBOX}/tools.log"
    export TOOL_LOG
    # Stubs that log any call. brew reports nothing installed (`brew list`
    # fails), so unchecking a component finds nothing to uninstall; the
    # removal behavior itself is in components_removal.bats.
    for tool in brew curl; do
        printf '#!/bin/sh\nprintf "%%s %%s\\n" "%s" "$*" >> "${TOOL_LOG}"\n' "${tool}" > "${SANDBOX}/bin/${tool}"
        chmod +x "${SANDBOX}/bin/${tool}"
    done
    printf '#!/bin/sh\nprintf "brew %%s\\n" "$*" >> "${TOOL_LOG}"\n[ "$1" = list ] && exit 1\nexit 0\n' > "${SANDBOX}/bin/brew"
    export PATH="${SANDBOX}/bin:${PATH}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

# _has <text> — assert $output contains <text> (a failing [[ ]] that is not the
# last command is ignored on bash 3.2).
_has() { case "${output}" in *"$1"*) return 0 ;; esac; echo "missing: $1 in: ${output}"; return 1; }

_require_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

# _tty_components <keys> — run the command on a pty reading <keys> (printf
# format) from fd 3, like the menu and tests of the other pickers.
_tty_components() {
    printf "$1" > "${SANDBOX}/keys"
    script -q /dev/null sh -c 'exec 3<"$1"; exec sh "$2"' _ "${SANDBOX}/keys" "${CMD}"
}

@test "--current prints none while nothing is recorded" {
    run sh "${CMD}" --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "none" ]
}

@test "components <ids> records them in DOTS_COMPONENTS and --current reports them" {
    run sh "${CMD}" tmux ghostty
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux ghostty}"' "${LOCAL_ZSH}"

    run sh "${CMD}" --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "tmux ghostty" ]
}

@test "components records ids in the fixed order, without duplicates" {
    run sh "${CMD}" ghostty tmux herdr-tui ghostty
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux herdr-tui ghostty}"' "${LOCAL_ZSH}"
}

@test "herdr-app implies herdr-core in the recorded selection" {
    run sh "${CMD}" herdr-app
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-herdr-core herdr-app}"' "${LOCAL_ZSH}"

    run sh "${CMD}" --current
    [ "${output}" = "herdr-core herdr-app" ]
}

@test "herdr-core alone does not bring the app" {
    run sh "${CMD}" herdr-core
    [ "${status}" -eq 0 ]
    run sh "${CMD}" --current
    [ "${output}" = "herdr-core" ]
}

@test "components replaces the previous selection in place" {
    sh "${CMD}" tmux
    run sh "${CMD}" ghostty
    [ "${status}" -eq 0 ]
    [ "$(grep -c DOTS_COMPONENTS "${LOCAL_ZSH}")" -eq 1 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-ghostty}"' "${LOCAL_ZSH}"
}

@test "components none records an empty selection, distinct from never recorded" {
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/detect.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
    . "${REPO_ROOT_REAL}/src/lib/components.sh"
    [ -z "$(components_recorded)" ]

    sh "${CMD}" tmux
    run sh "${CMD}" none
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"
    [ "$(components_recorded)" = "none" ]
    [ -z "$(components_selected)" ]

    run sh "${CMD}" --current
    [ "${output}" = "none" ]
}

@test "unknown component exits 1, names the supported ids and records nothing" {
    run sh "${CMD}" vim
    [ "${status}" -eq 1 ]
    _has "Unknown component 'vim'. Supported: tmux herdr-tui herdr-core herdr-app ghostty nvim fresh vscodium"
    [ ! -e "${LOCAL_ZSH}" ]
}

@test "an unknown id among valid ones leaves a recorded selection unchanged" {
    sh "${CMD}" tmux
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    run sh "${CMD}" ghostty vim
    [ "${status}" -eq 1 ]
    _has "Unknown component 'vim'"
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

@test "none cannot be combined with component ids" {
    sh "${CMD}" tmux
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    run sh "${CMD}" none ghostty
    [ "${status}" -eq 1 ]
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

@test "components without arguments and without a TTY prints usage and exits 2" {
    run sh "${CMD}"
    [ "${status}" -eq 2 ]
    _has "dots components"
    [ ! -e "${LOCAL_ZSH}" ]
}

@test "--help lists every component, the storage and the non-interactive forms" {
    run sh "${CMD}" --help
    [ "${status}" -eq 0 ]
    for id in tmux herdr-tui herdr-core herdr-app ghostty nvim fresh vscodium; do
        _has "${id}"
    done
    _has "DOTS_COMPONENTS"
    _has "--current"
    _has "none"
}

@test "the editor ids nvim, fresh and vscodium are independent and recorded in the fixed order" {
    run sh "${CMD}" vscodium nvim
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-nvim vscodium}"' "${LOCAL_ZSH}"
    run sh "${CMD}" --current
    [ "${output}" = "nvim vscodium" ]

    run sh "${CMD}" fresh
    [ "${status}" -eq 0 ]
    run sh "${CMD}" --current
    [ "${output}" = "fresh" ]

    run sh "${CMD}" --yes ghostty fresh nvim vscodium tmux
    [ "${status}" -eq 0 ]
    run sh "${CMD}" --current
    [ "${output}" = "tmux ghostty nvim fresh vscodium" ]
}

@test "a recorded selection without editor ids is left as it is and selecting an editor never selects another" {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-herdr-core herdr-app}"\n' > "${LOCAL_ZSH}"
    run sh "${CMD}" --current
    [ "${output}" = "herdr-core herdr-app" ]
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"
    run sh "${CMD}" --help
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
    . "${REPO_ROOT_REAL}/src/lib/components.sh"
    [ "$(components_normalize nvim)" = "nvim" ]
    [ "$(components_normalize vscodium)" = "vscodium" ]
    [ "$(components_normalize fresh)" = "fresh" ]
}

@test "the editor components have checklist labels" {
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
    . "${REPO_ROOT_REAL}/src/lib/components.sh"
    [ "${COMPONENT_IDS}" = "tmux herdr-tui herdr-core herdr-app ghostty nvim fresh vscodium" ]
    [ "$(component_label nvim)" = "Neovim (+ luarocks)" ]
    [ "$(component_label fresh)" = "Fresh editor (brew fresh-editor)" ]
    [ "$(component_label vscodium)" = "VSCodium (macOS cask, default GUI editor)" ]
}

@test "the command never installs: no curl, no brew call except the installed check" {
    sh "${CMD}" tmux herdr-app ghostty
    [ ! -e "${TOOL_LOG}" ]
    sh "${CMD}" none
    # unchecking only asks brew what is installed; nothing is uninstalled
    ! grep -v '^brew list ' "${TOOL_LOG}" || return 1
}

@test "picker: space checks rows, enter records them; nothing is checked by default" {
    _require_script || skip "PTY script syntax unavailable"

    run _tty_components '\n'
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-none}"' "${LOCAL_ZSH}"
    [[ "${output}" != *"[x]"* ]] || return 1

    run _tty_components ' jjj \n'
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux herdr-core herdr-app}"' "${LOCAL_ZSH}"
}

@test "picker: checking herdr-app shows herdr-core checked" {
    _require_script || skip "PTY script syntax unavailable"

    run _tty_components 'jjj \n'
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[x] Herdr core"* ]]
}

@test "picker starts from the recorded selection" {
    _require_script || skip "PTY script syntax unavailable"
    sh "${CMD}" tmux ghostty

    run _tty_components '\n'
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux ghostty}"' "${LOCAL_ZSH}"
}

@test "picker: q cancels with 130 and leaves local.zsh unchanged" {
    _require_script || skip "PTY script syntax unavailable"
    sh "${CMD}" tmux
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    run _tty_components ' jq'
    [ "${status}" -eq 130 ]
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

@test "select_components: rows, implication and cancel at the library level" {
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    REPO_ROOT="${REPO_ROOT_REAL}"
    . "${REPO_ROOT_REAL}/src/lib/log.sh"
    . "${REPO_ROOT_REAL}/src/lib/header.sh"
    . "${REPO_ROOT_REAL}/src/lib/tui.sh"
    . "${REPO_ROOT_REAL}/src/lib/detect.sh"
    . "${REPO_ROOT_REAL}/src/lib/theme.sh"
    . "${REPO_ROOT_REAL}/src/lib/components.sh"
    . "${REPO_ROOT_REAL}/src/lib/select.sh"
    # fd 3 carries the keys: redirect it inside a function, not on `run`.
    _select() { select_components "$1" 3<"${SANDBOX}/keys" 2>/dev/null; }

    printf 'jjj \n' > "${SANDBOX}/keys"
    run _select ""
    [ "${status}" -eq 0 ]
    [ "${output}" = "herdr-core herdr-app" ]

    printf '\n' > "${SANDBOX}/keys"
    run _select "ghostty tmux"
    [ "${output}" = "tmux ghostty" ]

    printf '\n' > "${SANDBOX}/keys"
    run _select ""
    [ "${status}" -eq 0 ]
    [ -z "${output}" ]

    printf 'q' > "${SANDBOX}/keys"
    run _select "tmux"
    [ "${status}" -eq 130 ]
    [ -z "${output}" ]
}

@test "dispatcher routes components, lists it in help and shows the menu row" {
    run sh "${REPO_ROOT_REAL}/dots" help
    _has "components  Choose which terminal components get installed."
    run sh "${REPO_ROOT_REAL}/dots" components --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "none" ]
    grep -Fq 'Maintain|components|' "${REPO_ROOT_REAL}/src/lib/tui.sh"
}
