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

@test "log_success prints a card with the elapsed-time title and its lines" {
    TUI_START_EPOCH="$(date +%s)"
    export TUI_START_EPOCH

    run log_success "Apply complete" "theme=kanagawa/dragon" "manifest=m.json"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf '│ Apply complete · 0s\n│ theme=kanagawa/dragon\n│ manifest=m.json')" ]
}

@test "log_success title carries elapsed-time suffix" {
    TUI_START_EPOCH="$(($(date +%s) - 3))"
    export TUI_START_EPOCH

    run log_success "Apply complete"

    [ "${status}" -eq 0 ]
    [[ "${output}" =~ Apply\ complete\ ·\ [0-9]+s ]]
}

@test "tui_card prints the title and lines behind a bar" {
    run tui_card 141 "Current active theme" "Theme:  kanagawa" "Flavor: dragon"

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf '│ Current active theme\n│ Theme:  kanagawa\n│ Flavor: dragon')" ]
}

# --- generic picker ------------------------------------------------------

# _choose <current> <keys> <items...> — tui_choose reading <keys> from fd 3.
_choose() {
    _cur="$1"; _k="$2"; shift 2
    printf "${_k}" > "${SANDBOX}/keys"
    tui_choose "Select flavor for kanagawa:" "${_cur}" "$@" 3<"${SANDBOX}/keys" 2>"${SANDBOX}/choose.err"
}

@test "tui_choose returns the item picked with j/k and enter" {
    run _choose "" 'jj\n' dragon lotus wave

    [ "${status}" -eq 0 ]
    [ "${output}" = "wave" ]
}

@test "tui_choose starts on the current item" {
    run _choose "lotus" '\n' dragon lotus wave

    [ "${status}" -eq 0 ]
    [ "${output}" = "lotus" ]
}

@test "tui_choose q, esc and end of input cancel with status 1 and no output" {
    run _choose "" 'q' dragon lotus wave
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]

    run _choose "" '\033' dragon lotus wave
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]

    run _choose "" '' dragon lotus wave
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
}

@test "tui_choose draws its header, items and key hints" {
    run _choose "lotus" 'q' dragon lotus wave

    [ "$(cat "${SANDBOX}/choose.err")" = "$(printf 'Select flavor for kanagawa:\n  dragon\n> lotus\n  wave\n\n↑↓/jk move · enter select · q cancel')" ]
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

# --- action menu (own key reader; keys come from fd 3) -------------------

# _menu <last> <keys> — run render_action_menu reading <keys> (printf format)
# from fd 3; stdout is the chosen value, stderr the drawn menu.
_menu() {
    printf "$2" > "${SANDBOX}/keys"
    render_action_menu "$1" 3<"${SANDBOX}/keys" 2>"${SANDBOX}/menu.err"
}

@test "q quits the menu" {
    run _menu "" 'q'

    [ "${status}" -eq 0 ]
    [ "${output}" = "quit" ]
}

@test "esc quits the menu" {
    run _menu "" '\033'

    [ "${status}" -eq 0 ]
    [ "${output}" = "quit" ]
}

@test "end of input quits the menu" {
    run _menu "" ''

    [ "${status}" -eq 0 ]
    [ "${output}" = "quit" ]
}

@test "enter runs the item under the cursor" {
    run _menu "" '\n'

    [ "${output}" = "update" ]
}

@test "j and down arrow move down, k and up arrow move up" {
    run _menu "" 'jj\n'
    [ "${output}" = "clean" ]

    run _menu "" '\033[B\033[B\033[A\n'
    [ "${output}" = "upgrade" ]

    run _menu "" 'jjk\n'
    [ "${output}" = "upgrade" ]
}

@test "cursor stops at the first and last items" {
    run _menu "" 'kk\n'
    [ "${output}" = "update" ]

    run _menu "" 'jjjjjjjjjjjj\n'
    [ "${output}" = "quit" ]
}

@test "last action is pre-selected" {
    run _menu "doctor" '\n'

    [ "${output}" = "doctor" ]
}

@test "menu draws group headers, actions with descriptions and key hints" {
    run _menu "" 'q'

    grep -qx "Maintain" "${SANDBOX}/menu.err"
    grep -qx "Appearance" "${SANDBOX}/menu.err"
    grep -qx "Danger" "${SANDBOX}/menu.err"
    grep -qx "> update     Apply dotfiles and the active theme" "${SANDBOX}/menu.err"
    grep -qx "  doctor     Health checks that change nothing" "${SANDBOX}/menu.err"
    grep -qx "  uninstall  ⚠ Remove managed symlinks and manifest" "${SANDBOX}/menu.err"
    grep -qx "↑↓/jk move · enter run · q quit" "${SANDBOX}/menu.err"
    [ "$(grep -E '^[> ] [a-z]+ ' "${SANDBOX}/menu.err" | awk '{print ($1==">") ? $2 : $1}' | tr '\n' ' ')" = "update upgrade clean doctor theme prompt uninstall help quit " ]
}

# --- confirm ---------------------------------------------------------------

# _confirm <default> <keys> — tui_confirm reading <keys> from fd 3.
_confirm() {
    printf "$2" > "${SANDBOX}/keys"
    tui_confirm "Apply selection?" "$1" 3<"${SANDBOX}/keys" 2>"${SANDBOX}/confirm.err"
}

@test "tui_confirm y or Y answers yes" {
    run _confirm n 'y'
    [ "${status}" -eq 0 ]
    run _confirm n 'Y'
    [ "${status}" -eq 0 ]
}

@test "tui_confirm n or N answers no" {
    run _confirm y 'n'
    [ "${status}" -eq 1 ]
    run _confirm y 'N'
    [ "${status}" -eq 1 ]
}

@test "tui_confirm enter takes the default" {
    run _confirm n '\n'
    [ "${status}" -eq 1 ]
    run _confirm y '\n'
    [ "${status}" -eq 0 ]
}

@test "tui_confirm q, esc and end of input cancel with 130" {
    run _confirm y 'q'
    [ "${status}" -eq 130 ]
    run _confirm y '\033'
    [ "${status}" -eq 130 ]
    run _confirm y ''
    [ "${status}" -eq 130 ]
}

@test "tui_confirm ignores other keys until an answer" {
    run _confirm n 'xjz y'
    [ "${status}" -eq 0 ]
}

@test "tui_confirm shows the question with the default capitalised" {
    run _confirm n 'n'
    [ "$(head -1 "${SANDBOX}/confirm.err")" = "Apply selection? [y/N] n" ]

    run _confirm y 'y'
    [ "$(head -1 "${SANDBOX}/confirm.err")" = "Apply selection? [Y/n] y" ]
}

@test "confirm_apply does not apply on enter (default No)" {
    . "${REPO_ROOT_REAL}/src/lib/select.sh"
    printf '\n' > "${SANDBOX}/keys"

    run confirm_apply catppuccin mocha 3<"${SANDBOX}/keys"

    [ "${status}" -eq 1 ]
    [[ "${output}" == *"Apply selection? [y/N]"* ]]
}

# --- caller traps and no controlling terminal -------------------------------

# _has / _lacks <text> — assert $output contains / lacks <text>. `[[ ]]` is not
# used: on bash 3.2 a failing `[[ ]]` that is not the last command is ignored.
_has() {
    case "${output}" in *"$1"*) return 0 ;; esac
    echo "output lacks '$1': ${output}" >&2
    return 1
}
_lacks() {
    case "${output}" in *"$1"*) echo "output has '$1': ${output}" >&2; return 1 ;; esac
    return 0
}

# _sh_tui <script> — run <script> in a fresh `sh -c` with the libs sourced.
# $1 inside the script is the repo root, $2 a file holding the keys.
_sh_tui() {
    sh -c '
        REPO_ROOT="$1"
        . "${REPO_ROOT}/src/lib/paths.sh"
        . "${REPO_ROOT}/src/lib/log.sh"
        . "${REPO_ROOT}/src/lib/header.sh"
        . "${REPO_ROOT}/src/lib/tui.sh"
        '"$1"'
    ' _ "${REPO_ROOT_REAL}" "${SANDBOX}/keys"
}

@test "tui_confirm keeps the caller's INT trap" {
    printf 'n' > "${SANDBOX}/keys"

    run _sh_tui "
        trap 'echo caller' INT
        tui_confirm 'x' y 3<\"\$2\" 2>/dev/null
        echo rc=\$?
        trap"

    _has 'rc=1'
    _has 'echo caller'
    _has 'INT'
}

@test "tui_confirm leaves no INT or TERM trap when the caller had none" {
    printf 'n' > "${SANDBOX}/keys"

    run _sh_tui "
        tui_confirm 'x' y 3<\"\$2\" 2>/dev/null
        echo rc=\$?
        trap"

    _has 'rc=1'
    _lacks 'INT'
    _lacks 'TERM'
}

@test "tui_choose keeps the caller's INT trap and leaks none" {
    printf '\n' > "${SANDBOX}/keys"

    run _sh_tui "
        trap 'echo caller' INT
        picked=\$(tui_choose 'h' '' a b 3<\"\$2\" 2>/dev/null)
        echo picked=\$picked
        trap"

    _has 'picked=a'
    _has 'echo caller'

    run _sh_tui "
        picked=\$(tui_choose 'h' '' a b 3<\"\$2\" 2>/dev/null)
        trap"

    _lacks 'INT'
    _lacks 'TERM'
}

@test "_tui_pick (not in a subshell) keeps the caller's INT trap or leaves none" {
    printf '\n' > "${SANDBOX}/keys"

    run _sh_tui "
        trap 'echo caller' INT
        _TUI_CHOOSE_HEADER=h _TUI_CHOOSE_ITEMS='a
b'
        _tui_pick _tui_choose_frame 2 1 3<\"\$2\" 2>/dev/null >/dev/null
        trap"

    _has 'echo caller'

    run _sh_tui "
        _TUI_CHOOSE_HEADER=h _TUI_CHOOSE_ITEMS='a
b'
        _tui_pick _tui_choose_frame 2 1 3<\"\$2\" 2>/dev/null >/dev/null
        trap"

    _lacks 'INT'
    _lacks 'TERM'
}

# _no_tty <script> — _sh_tui without a controlling terminal (own session).
_no_tty() {
    perl -MPOSIX -e 'POSIX::setsid(); exec @ARGV' sh -c '
        REPO_ROOT="$1"
        . "${REPO_ROOT}/src/lib/paths.sh"
        . "${REPO_ROOT}/src/lib/log.sh"
        . "${REPO_ROOT}/src/lib/header.sh"
        . "${REPO_ROOT}/src/lib/tui.sh"
        '"$1"'
    ' _ "${REPO_ROOT_REAL}" 2>&1 </dev/null
}

@test "tui_confirm cancels with 130 and does not abort when there is no tty" {
    run _no_tty 'tui_confirm "x" n 3<&-; echo "after rc=$?"'

    _lacks 'Device not configured'
    _has 'after rc=130'
}

@test "tui_choose cancels with 1 and does not abort when there is no tty" {
    run _no_tty 'tui_choose "h" "" a b 3<&-; echo "after rc=$?"'

    _lacks 'Device not configured'
    _has 'after rc=1'
}

@test "render_action_menu prints quit and does not abort when there is no tty" {
    run _no_tty 'render_action_menu "" 3<&-; echo "after rc=$?"'

    _lacks 'Device not configured'
    _has 'quit'
    _has 'after rc=0'
}
