#!/usr/bin/env bats
# tests/tui_helpers.bats
# bats-core unit tests for lib/tui.sh.

REPO_ROOT_REAL="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"

setup() {
    SANDBOX="$(mktemp -d)"
    export REPO_ROOT="${SANDBOX}"
    MOCKBIN="${SANDBOX}/bin"
    mkdir -p "${MOCKBIN}"
    export PATH="${MOCKBIN}:${PATH}"

    # shellcheck source=../src/lib/paths.sh
    . "${REPO_ROOT_REAL}/src/lib/paths.sh"
    # shellcheck source=../src/lib/header.sh
    . "${REPO_ROOT_REAL}/src/lib/header.sh"
    render_header() {
        printf 'theme=%s subtitle=%s\n' "$1" "$2"
    }
    # shellcheck source=../src/lib/tui.sh
    . "${REPO_ROOT_REAL}/src/lib/tui.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "render_command_banner reads manifest theme and flavor" {
    cat > "${REPO_ROOT}/manifest.json" <<'JSON'
{"theme":"catppuccin","flavor":"mocha"}
JSON

    run render_command_banner "Apply"

    [ "${status}" -eq 0 ]
    [ "${output}" = "theme=catppuccin/mocha subtitle=Apply" ]
}

@test "render_command_banner falls back to kanagawa" {
    run render_command_banner "Doctor"

    [ "${status}" -eq 0 ]
    [ "${output}" = "theme=kanagawa subtitle=Doctor" ]
}

@test "log_success invokes gum style with expected flags" {
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
printf '%s\n' "$*" > "${GUM_ARGS_FILE}"
printf 'gum:%s\n' "$*"
SH
    chmod +x "${MOCKBIN}/gum"
    export GUM_ARGS_FILE="${SANDBOX}/gum.args"

    run log_success "Apply complete" "theme=kanagawa/dragon" "manifest=${REPO_ROOT}/manifest.json"

    [ "${status}" -eq 0 ]
    grep -q -- "--border rounded" "${GUM_ARGS_FILE}"
    grep -q -- "--border-foreground 141" "${GUM_ARGS_FILE}"
    grep -q -- "--padding 1 2" "${GUM_ARGS_FILE}"
    grep -q -- "--bold" "${GUM_ARGS_FILE}"
}

@test "log_success title carries elapsed-time suffix" {
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
printf '%s\n' "$*"
SH
    chmod +x "${MOCKBIN}/gum"
    TUI_START_EPOCH="$(($(date +%s) - 3))"
    export TUI_START_EPOCH

    run log_success "Apply complete"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ Apply\ complete\ ·\ [0-9]+s ]]
}

# --- compact menu status line -------------------------------------------

_git_repo_at_root() {
    git -C "${REPO_ROOT}" init -q
    git -C "${REPO_ROOT}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init
}

@test "render_menu_status shows brand, theme/flavor and prompt engine" {
    cat > "${REPO_ROOT}/manifest.json" <<'JSON'
{"theme":"catppuccin","flavor":"mocha","prompt":"starship"}
JSON

    run render_menu_status

    [ "${status}" -eq 0 ]
    [ "${output}" = "jals1212 DOTS · catppuccin/mocha · starship" ]
}

@test "render_menu_status omits prompt when manifest has none" {
    run render_menu_status

    [ "${status}" -eq 0 ]
    [ "${output}" = "jals1212 DOTS · kanagawa" ]
}

@test "render_menu_status reports a clean git tree" {
    cat > "${REPO_ROOT}/manifest.json" <<'JSON'
{"theme":"kanagawa","flavor":"dragon","prompt":"p10k"}
JSON
    _git_repo_at_root
    git -C "${REPO_ROOT}" add -A
    git -C "${REPO_ROOT}" -c user.name=t -c user.email=t@t commit -q -m manifest

    run render_menu_status

    [ "${status}" -eq 0 ]
    [ "${output}" = "jals1212 DOTS · kanagawa/dragon · p10k · ✓ clean" ]
}

@test "render_menu_status counts uncommitted git changes" {
    _git_repo_at_root
    git -C "${REPO_ROOT}" add -A
    git -C "${REPO_ROOT}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
    : > "${REPO_ROOT}/a"
    : > "${REPO_ROOT}/b"

    run render_menu_status

    [ "${status}" -eq 0 ]
    [ "${output}" = "jals1212 DOTS · kanagawa · 2 changed" ]
}

# --- action menu --------------------------------------------------------

_mock_gum_args() {
    cat > "${MOCKBIN}/gum" <<'SH'
#!/bin/sh
for a in "$@"; do printf '%s\n' "$a"; done > "${GUM_ARGS_FILE}"
printf 'update\n'
SH
    chmod +x "${MOCKBIN}/gum"
    export GUM_ARGS_FILE="${SANDBOX}/gum.args"
}

@test "render_action_menu lists grouped actions with descriptions" {
    _mock_gum_args

    run render_action_menu ""

    [ "${status}" -eq 0 ]
    [ "${output}" = "update" ]
    grep -qx -- "--label-delimiter=|" "${GUM_ARGS_FILE}"
    [ "$(grep -c '|' "${GUM_ARGS_FILE}")" -eq 10 ]
    grep '|' "${GUM_ARGS_FILE}" | grep -v -- '--' | sed 's/.*|//' | tr '\n' ' ' > "${SANDBOX}/values"
    [ "$(cat "${SANDBOX}/values")" = "update upgrade clean doctor theme prompt uninstall help quit " ]
    grep -qx "update     Apply dotfiles and the active theme|update" "${GUM_ARGS_FILE}"
    grep -qx "uninstall  ⚠ Remove managed symlinks and manifest|uninstall" "${GUM_ARGS_FILE}"
}

@test "render_action_menu pre-selects the last action by its label" {
    _mock_gum_args

    run render_action_menu "doctor"

    [ "${status}" -eq 0 ]
    grep -qx -- "--selected=doctor     Health checks that change nothing" "${GUM_ARGS_FILE}"
}

@test "render_action_menu uses the theme accent for cursor and header" {
    _mock_gum_args

    run render_action_menu ""

    grep -qx -- "--cursor.foreground=141" "${GUM_ARGS_FILE}"
    grep -qx -- "--selected.foreground=141" "${GUM_ARGS_FILE}"
    grep -qx -- "--header.foreground=141" "${GUM_ARGS_FILE}"
}

@test "menu labels contain no commas (gum splits --selected on commas)" {
    _mock_gum_args

    run render_action_menu ""

    [ "$(grep '|' "${GUM_ARGS_FILE}" | grep -v -- '--' | grep -c ',')" -eq 0 ]
}
