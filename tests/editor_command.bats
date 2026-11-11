#!/usr/bin/env bats
bats_require_minimum_version 1.5.0
# tests/editor_command.bats
# Verifies `./dots editor`: the machine-local terminal $EDITOR/$VISUAL choice
# between nvim (default) and fresh, recorded as DOTS_EDITOR in
# ~/.config/zsh/local.zsh and exported by .zshenv after local.zsh is sourced.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export HOME="${SANDBOX}/home"
    export XDG_STATE_HOME="${HOME}/.local/state"
    mkdir -p "${HOME}/.config/zsh" "${SANDBOX}/bin"
    export NO_COLOR=1
    LOCAL_ZSH="${HOME}/.config/zsh/local.zsh"
    EDITOR_CMD="${REPO_ROOT_REAL}/src/commands/editor.sh"
    # Never touch the host's Homebrew or network: stub the tools on PATH.
    for _tool in brew curl; do
        printf '#!/bin/sh\nprintf "%%s\\n" "$*" >> "${SANDBOX_CALLS}"\nexit 1\n' > "${SANDBOX}/bin/${_tool}"
        chmod +x "${SANDBOX}/bin/${_tool}"
    done
    export SANDBOX_CALLS="${SANDBOX}/calls.log"
    export PATH="${SANDBOX}/bin:${PATH}"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "--current defaults to nvim without any recorded choice" {
    run sh "${EDITOR_CMD}" --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "nvim" ]
}

@test "editor fresh records DOTS_EDITOR exactly and --current reports it" {
    run sh "${EDITOR_CMD}" fresh
    [ "${status}" -eq 0 ]
    grep -Fqx 'export DOTS_EDITOR="${DOTS_EDITOR:-fresh}"' "${LOCAL_ZSH}"
    [[ "${output}" == *"Editor set"* ]]
    [[ "${output}" == *"Open a new shell to use it"* ]]

    run sh "${EDITOR_CMD}" --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "fresh" ]
}

@test "editor nvim replaces a previous choice in place" {
    sh "${EDITOR_CMD}" fresh
    run sh "${EDITOR_CMD}" nvim
    [ "${status}" -eq 0 ]
    [ "$(grep -c DOTS_EDITOR "${LOCAL_ZSH}")" -eq 1 ]
    grep -Fqx 'export DOTS_EDITOR="${DOTS_EDITOR:-nvim}"' "${LOCAL_ZSH}"
}

@test "unknown editor exits 1 with the exact error and leaves local.zsh unchanged" {
    sh "${EDITOR_CMD}" fresh
    cp "${LOCAL_ZSH}" "${SANDBOX}/local.before"

    run --separate-stderr sh "${EDITOR_CMD}" emacs
    [ "${status}" -eq 1 ]
    [[ "${stderr}" == *"Unknown editor 'emacs'. Supported: nvim fresh"* ]]
    cmp -s "${LOCAL_ZSH}" "${SANDBOX}/local.before"
}

@test "unknown editor with no local.zsh writes nothing" {
    run sh "${EDITOR_CMD}" emacs
    [ "${status}" -eq 1 ]
    [ ! -e "${LOCAL_ZSH}" ]
}

@test "editor with too many arguments prints usage on stderr and exits 2" {
    run --separate-stderr sh "${EDITOR_CMD}" nvim fresh
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"USAGE"* ]]
    [ ! -e "${LOCAL_ZSH}" ]
}

@test "editor without arguments and without a TTY prints usage on stderr and exits 2" {
    run --separate-stderr sh "${EDITOR_CMD}" < /dev/null
    [ "${status}" -eq 2 ]
    [[ "${stderr}" == *"USAGE"* ]]
    [ ! -e "${LOCAL_ZSH}" ]
}

@test "--help and -h list both editors and exit 0" {
    for flag in --help -h; do
        run sh "${EDITOR_CMD}" "${flag}"
        [ "${status}" -eq 0 ]
        [[ "${output}" == *"nvim"* ]]
        [[ "${output}" == *"fresh"* ]]
        [[ "${output}" == *"DOTS_EDITOR"* ]]
    done
}

@test "choosing an editor whose component is not selected warns and still succeeds" {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-tmux}"\n' > "${LOCAL_ZSH}"
    run sh "${EDITOR_CMD}" fresh
    [ "${status}" -eq 0 ]
    [[ "${output}" == *"[WARN]"*"fresh"*"./dots components"* ]]
    grep -Fqx 'export DOTS_EDITOR="${DOTS_EDITOR:-fresh}"' "${LOCAL_ZSH}"
}

@test "choosing an editor whose component is selected does not warn" {
    printf 'export DOTS_COMPONENTS="${DOTS_COMPONENTS:-nvim fresh}"\n' > "${LOCAL_ZSH}"
    run sh "${EDITOR_CMD}" fresh
    [ "${status}" -eq 0 ]
    [[ "${output}" != *"[WARN]"* ]]
}

@test "editor never calls brew or curl" {
    run sh "${EDITOR_CMD}" fresh
    [ "${status}" -eq 0 ]
    [ ! -e "${SANDBOX_CALLS}" ]
}

# _zshenv_vars — print "EDITOR VISUAL" after sourcing the repo .zshenv with a
# sandbox ZDOTDIR whose local.zsh holds $1 (may be empty for none).
_zshenv_vars() {
    command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
    export ZDOTDIR="${SANDBOX}/zdot"
    mkdir -p "${ZDOTDIR}"
    [ -z "${1:-}" ] || printf '%s\n' "$1" > "${ZDOTDIR}/local.zsh"
    env -u DOTS_EDITOR -u EDITOR -u VISUAL ZDOTDIR="${ZDOTDIR}" \
        zsh -f -c 'source "'"${REPO_ROOT_REAL}"'/content/home/.config/zsh/.zshenv"; print -r -- "$EDITOR $VISUAL"'
}

@test ".zshenv exports EDITOR and VISUAL from DOTS_EDITOR in local.zsh" {
    run _zshenv_vars 'export DOTS_EDITOR="${DOTS_EDITOR:-fresh}"'
    [ "${status}" -eq 0 ]
    [ "${output}" = "fresh fresh" ]
}

@test ".zshenv defaults EDITOR and VISUAL to nvim" {
    run _zshenv_vars ''
    [ "${status}" -eq 0 ]
    [ "${output}" = "nvim nvim" ]

    run _zshenv_vars 'export DOTS_THEME="${DOTS_THEME:-x}"'
    [ "${status}" -eq 0 ]
    [ "${output}" = "nvim nvim" ]
}

@test "a DOTS_EDITOR set in the environment wins over local.zsh" {
    command -v zsh >/dev/null 2>&1 || skip "zsh unavailable"
    export ZDOTDIR="${SANDBOX}/zdot"
    mkdir -p "${ZDOTDIR}"
    printf 'export DOTS_EDITOR="${DOTS_EDITOR:-nvim}"\n' > "${ZDOTDIR}/local.zsh"
    run env -u EDITOR -u VISUAL DOTS_EDITOR=fresh ZDOTDIR="${ZDOTDIR}" \
        zsh -f -c 'source "'"${REPO_ROOT_REAL}"'/content/home/.config/zsh/.zshenv"; print -r -- "$EDITOR $VISUAL"'
    [ "${status}" -eq 0 ]
    [ "${output}" = "fresh fresh" ]
}

@test "dispatcher routes editor and documents it in help next to font" {
    run sh "${REPO_ROOT_REAL}/dots" help
    [[ "${output}" == *'  editor      Choose the terminal $EDITOR (nvim | fresh).'* ]]
    font_line="$(printf '%s\n' "${output}" | grep -n '^  font ' | cut -d: -f1)"
    editor_line="$(printf '%s\n' "${output}" | grep -n '^  editor ' | cut -d: -f1)"
    [ "$((editor_line - font_line))" -eq 1 ]
    run sh "${REPO_ROOT_REAL}/dots" editor --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "nvim" ]
}

@test "the menu lists the editor row right after font" {
    grep -Fqx 'Appearance|editor|Choose terminal editor: nvim or fresh' \
        <(sed -n '/^_TUI_MENU_ROWS=/,/quit$/p' "${REPO_ROOT_REAL}/src/lib/tui.sh" | sed "s/^_TUI_MENU_ROWS='//")
    font_n="$(grep -n '^Appearance|font|' "${REPO_ROOT_REAL}/src/lib/tui.sh" | cut -d: -f1)"
    editor_n="$(grep -n '^Appearance|editor|' "${REPO_ROOT_REAL}/src/lib/tui.sh" | cut -d: -f1)"
    [ "$((editor_n - font_n))" -eq 1 ]
}

@test "the menu dispatch runs the editor command" {
    run sh -c "cd '${REPO_ROOT_REAL}' && grep -n '^        editor)' dots"
    [ "${status}" -eq 0 ]
    [[ "${output}" == *'path_command editor'* ]]
}

@test "font command behavior is unchanged: --current default and invalid font" {
    run sh "${REPO_ROOT_REAL}/src/commands/font.sh" --current
    [ "${status}" -eq 0 ]
    [ "${output}" = "jetbrains-mono" ]
    run sh "${REPO_ROOT_REAL}/src/commands/font.sh" comic
    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Unknown font 'comic'. Supported: jetbrains-mono iosevka"* ]]
}
