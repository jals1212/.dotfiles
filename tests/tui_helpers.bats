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
    # shellcheck source=../src/lib/tui.sh
    . "${REPO_ROOT_REAL}/src/lib/tui.sh"
}

teardown() {
    rm -rf "${SANDBOX}"
}

@test "render_command_banner is one line: brand, title, theme/flavor and prompt" {
    cat > "${REPO_ROOT}/manifest.json" <<'JSON'
{"theme":"catppuccin","flavor":"mocha","prompt":"starship"}
JSON

    run render_command_banner "Doctor"

    [ "${status}" -eq 0 ]
    [ "${output}" = "⁘ jals1212 DOTS · Doctor · catppuccin/mocha · starship" ]
}

@test "render_command_banner falls back to kanagawa and shows git state" {
    git -C "${REPO_ROOT}" init -q
    git -C "${REPO_ROOT}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m init

    run render_command_banner "Doctor"

    [ "${status}" -eq 0 ]
    [ "${output}" = "⁘ jals1212 DOTS · Doctor · kanagawa · ✓ clean" ]
}

@test "render_subcommand_banner prints the one-line header outside the menu" {
    run env -u DOTS_MENU_DISPATCH sh -c '. "$1/src/lib/paths.sh"; . "$1/src/lib/log.sh"; . "$1/src/lib/tui.sh"; render_subcommand_banner Clean' _ "${REPO_ROOT_REAL}"

    [ "${status}" -eq 0 ]
    [[ "${output}" == "⁘ jals1212 DOTS · Clean"* ]] || return 1
    [ "$(printf '%s\n' "${output}" | wc -l | tr -d ' ')" -eq 1 ]
}

@test "render_subcommand_banner prints nothing under DOTS_MENU_DISPATCH=1" {
    DOTS_MENU_DISPATCH=1 run render_subcommand_banner "Clean"

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
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
    [ "${output}" = "⁘ jals1212 DOTS · catppuccin/mocha · starship" ]
}

@test "render_menu_status omits prompt when manifest has none" {
    run render_menu_status

    [ "${status}" -eq 0 ]
    [ "${output}" = "⁘ jals1212 DOTS · kanagawa" ]
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
    [ "${output}" = "⁘ jals1212 DOTS · kanagawa/dragon · p10k · ✓ clean" ]
}

@test "render_menu_status counts uncommitted git changes" {
    _git_repo_at_root
    git -C "${REPO_ROOT}" add -A
    git -C "${REPO_ROOT}" -c user.name=t -c user.email=t@t commit -q --allow-empty -m base
    : > "${REPO_ROOT}/a"
    : > "${REPO_ROOT}/b"

    run render_menu_status

    [ "${status}" -eq 0 ]
    [ "${output}" = "⁘ jals1212 DOTS · kanagawa · 2 changed" ]
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

    run _menu "" 'jjjj\n'
    [ "${output}" = "components" ]

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
    grep -qx "  components Choose which terminal components get installed" "${SANDBOX}/menu.err"
    grep -qx "  uninstall  ⚠ Remove managed symlinks and manifest" "${SANDBOX}/menu.err"
    grep -qx "↑↓/jk move · enter run · q quit" "${SANDBOX}/menu.err"
    [ "$(grep -E '^[> ] [a-z]+ ' "${SANDBOX}/menu.err" | awk '{print ($1==">") ? $2 : $1}' | tr '\n' ' ')" = "update upgrade clean doctor components theme prompt font editor uninstall help quit " ]
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

@test "tui_confirm restores a multi-line caller trap verbatim" {
    printf 'n' > "${SANDBOX}/keys"

    run _sh_tui "
        trap 'echo A
trap -- x INT
echo B' INT
        tui_confirm 'x' y 3<\"\$2\" 2>/dev/null
        trap"

    _has 'trap -- x INT'
    _lacks '_tui_replay_trap'
}

# --- subshell bodies: nothing to save, nothing to leak ----------------------

@test "tui_confirm and tui_choose create no temp file" {
    cat > "${MOCKBIN}/mktemp" <<EOS
#!/bin/sh
echo "\$*" >> "${SANDBOX}/mktemp.log"
exec /usr/bin/mktemp "\$@"
EOS
    chmod +x "${MOCKBIN}/mktemp"
    : > "${SANDBOX}/mktemp.log"

    run _confirm n 'n'
    [ "${status}" -eq 1 ]

    run _choose "" 'q' a b
    [ "${status}" -eq 1 ]

    [ ! -s "${SANDBOX}/mktemp.log" ]
}

@test "dash: a caller INT trap survives tui_confirm even when mktemp fails" {
    command -v dash >/dev/null 2>&1 || skip "dash not installed"
    printf 'n' > "${SANDBOX}/keys"

    run dash -c '
        REPO_ROOT="$1"
        . "${REPO_ROOT}/src/lib/paths.sh"
        . "${REPO_ROOT}/src/lib/log.sh"
        . "${REPO_ROOT}/src/lib/header.sh"
        . "${REPO_ROOT}/src/lib/tui.sh"
        mktemp() { return 1; }
        trap "echo caller" INT
        tui_confirm "x" y 3<"$2" 2>/dev/null
        echo rc=$?
        trap' _ "${REPO_ROOT_REAL}" "${SANDBOX}/keys"

    _has 'rc=1'
    _has 'echo caller'
    _has 'INT'
}

# --- Ctrl-C at a confirm or picker aborts the caller (real PTY) --------------

_require_bsd_script() {
    command -v script >/dev/null 2>&1 || return 1
    script -q /dev/null env true >/dev/null 2>&1
}

# _pty_run <shell> <key printf-format> <caller script> — run <caller script>
# (libs sourced) with <shell> under a real PTY, send <key> after a delay and
# collect the output in $output. An outer shell keeps catching INT (so only
# the caller is judged), prints "STATUS=<caller status>" and saves `stty -a`
# to ${SANDBOX}/after.
_pty_run() {
    _pr_shell="$1"; _pr_key="$2"
    cat > "${SANDBOX}/caller.sh" <<EOS
REPO_ROOT="${REPO_ROOT_REAL}"
. "\${REPO_ROOT}/src/lib/paths.sh"
. "\${REPO_ROOT}/src/lib/log.sh"
. "\${REPO_ROOT}/src/lib/header.sh"
. "\${REPO_ROOT}/src/lib/tui.sh"
$3
EOS
    cat > "${SANDBOX}/outer.sh" <<EOS
trap : INT
"${_pr_shell}" "${SANDBOX}/caller.sh"
echo "STATUS=\$?"
sleep 1  # a signalled caller can die before its picker subshell restored stty
stty -a > "${SANDBOX}/after"
EOS
    # bats keeps its own fd 3 open; close it so the caller opens /dev/tty.
    run bash -c '
        exec 3<&- 3>&-
        { sleep 2; printf "$1"; sleep 2; } | script -q /dev/null "$2" "$3"
    ' _ "${_pr_key}" "${_pr_shell}" "${SANDBOX}/outer.sh"
}

# _stty_cooked — the saved `stty -a` still has canonical mode and echo on.
_stty_cooked() {
    ! tr ' ;' '\n\n' < "${SANDBOX}/after" | grep -qx -e '-icanon' -e '-echo'
}

# _each_pty_shell <fn> — run <fn> <shell> for /bin/sh and, when installed, dash.
_each_pty_shell() {
    _require_bsd_script || skip "PTY script syntax unavailable"
    "$1" /bin/sh
    if [ -x /bin/dash ]; then
        "$1" /bin/dash
    fi
}

_ctrlc_confirm_aborts() {
    _pty_run "$1" '\003' 'tui_confirm "x" n; echo "AFTER rc=$?"'
    _lacks 'AFTER'
    _has 'STATUS=130'
    _stty_cooked
}

@test "Ctrl-C during tui_confirm aborts the caller and restores stty" {
    _each_pty_shell _ctrlc_confirm_aborts
}

_ctrlc_confirm_trap() {
    _pty_run "$1" '\003' "trap 'echo CALLER_INT; exit 7' INT
tui_confirm 'x' n; echo \"AFTER rc=\$?\""
    _has 'CALLER_INT'
    _lacks 'AFTER'
    _has 'STATUS=7'
    _stty_cooked
}

@test "Ctrl-C during tui_confirm runs the caller's INT trap" {
    _each_pty_shell _ctrlc_confirm_trap
}

_ctrlc_choose_aborts() {
    _pty_run "$1" '\003' 'tui_choose "h" "" a b; echo "AFTER rc=$?"'
    _lacks 'AFTER'
    _has 'STATUS=130'
    _stty_cooked
}

@test "Ctrl-C during tui_choose aborts the caller and restores stty" {
    _each_pty_shell _ctrlc_choose_aborts
}

_cancel_keys_continue() {
    _pty_run "$1" 'q' 'tui_confirm "x" n; echo "AFTER rc=$?"'
    _has 'AFTER rc=130'
    _has 'STATUS=0'
    _pty_run "$1" '\033' 'tui_confirm "x" n; echo "AFTER rc=$?"'
    _has 'AFTER rc=130'
    _pty_run "$1" 'q' 'tui_choose "h" "" a b; echo "AFTER rc=$?"'
    _has 'AFTER rc=1'
    _stty_cooked
}

@test "q and esc at a confirm or picker still cancel and the caller continues" {
    _each_pty_shell _cancel_keys_continue
}

# --- checklist (tui_checklist: checkboxes, space toggles) -------------------

# _checklist <checked> <implies> <keys> <item...> — tui_checklist reading <keys>
# (printf format) from fd 3; stdout is the checked ids in item order, stderr
# the drawn frames. Items are "id|label".
_checklist() {
    _ck="$1"; _imp="$2"; _k="$3"; shift 3
    printf "${_k}" > "${SANDBOX}/keys"
    tui_checklist "Pick tools:" "${_ck}" "${_imp}" "$@" 3<"${SANDBOX}/keys" 2>"${SANDBOX}/checklist.err"
}

@test "tui_checklist space toggles the row under the cursor and enter confirms" {
    run _checklist "" "" ' j j\n' 'a|Alpha' 'b|Beta' 'c|Gamma'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'a\nb')" ]
}

@test "tui_checklist starts from the checked ids and space unchecks" {
    run _checklist "a c" "" '\n' 'a|Alpha' 'b|Beta' 'c|Gamma'
    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'a\nc')" ]

    run _checklist "a c" "" ' \n' 'a|Alpha' 'b|Beta' 'c|Gamma'
    [ "${status}" -eq 0 ]
    [ "${output}" = "c" ]
}

@test "tui_checklist prints ids in item order whatever the toggle order" {
    run _checklist "" "" 'jj jk\033[B\033[A \n' 'a|Alpha' 'b|Beta' 'c|Gamma'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'b\nc')" ]
}

@test "tui_checklist cursor stops at the first and last rows" {
    run _checklist "" "" 'kk jjjjjj \n' 'a|Alpha' 'b|Beta' 'c|Gamma'

    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'a\nc')" ]
}

@test "tui_checklist confirms an empty selection with status 0 and no output" {
    run _checklist "" "" '\n' 'a|Alpha' 'b|Beta'

    [ "${status}" -eq 0 ]
    [ -z "${output}" ]
}

@test "tui_checklist q, esc and end of input cancel with status 1 and no output" {
    run _checklist "a" "" ' jjq' 'a|Alpha' 'b|Beta'
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]

    run _checklist "a" "" 'j \033' 'a|Alpha' 'b|Beta'
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]

    run _checklist "a" "" ' ' 'a|Alpha' 'b|Beta'
    [ "${status}" -eq 1 ]
    [ -z "${output}" ]
}

@test "tui_checklist draws the header, checkboxes, cursor and key hints" {
    run _checklist "b" "" 'q' 'a|Alpha' 'b|Beta'

    grep -Fqx "Pick tools:" "${SANDBOX}/checklist.err"
    grep -Fqx "> [ ] Alpha" "${SANDBOX}/checklist.err"
    grep -Fqx "  [x] Beta" "${SANDBOX}/checklist.err"
    grep -Fqx "↑↓/jk move · space toggle · enter confirm · q cancel" "${SANDBOX}/checklist.err"
}

@test "tui_checklist checking a row checks the rows it implies" {
    run _checklist "" "app>core" 'jj \n' 'tmux|Tmux' 'core|Core' 'app|App'
    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'core\napp')" ]
    grep -Fqx "  [x] Core" "${SANDBOX}/checklist.err"
}

@test "tui_checklist shows an implied row checked when the implying row starts checked" {
    run _checklist "app" "app>core" 'q' 'core|Core' 'app|App'

    grep -Fqx "> [x] Core" "${SANDBOX}/checklist.err"
    run _checklist "app" "app>core" '\n' 'core|Core' 'app|App'
    [ "${output}" = "$(printf 'core\napp')" ]
}

@test "tui_checklist keeps an implied row checked while the implying row is" {
    run _checklist "app" "app>core" ' \n' 'core|Core' 'app|App'
    [ "${status}" -eq 0 ]
    [ "${output}" = "$(printf 'core\napp')" ]
}

@test "tui_checklist unchecking the implying row leaves the implied row checked" {
    run _checklist "app" "app>core" 'j \n' 'core|Core' 'app|App'
    [ "${status}" -eq 0 ]
    [ "${output}" = "core" ]
}

@test "tui_checklist keeps the caller's INT trap and leaks none" {
    printf ' \n' > "${SANDBOX}/keys"

    run _sh_tui "
        trap 'echo caller' INT
        picked=\$(tui_checklist 'h' '' '' 'a|A' 'b|B' 3<\"\$2\" 2>/dev/null)
        echo picked=\$picked
        trap"
    _has 'picked=a'
    _has 'echo caller'

    run _sh_tui "
        picked=\$(tui_checklist 'h' '' '' 'a|A' 3<\"\$2\" 2>/dev/null)
        trap"
    _lacks 'INT'
    _lacks 'TERM'
}

@test "tui_checklist cancels with 1 and does not abort when there is no tty" {
    run _no_tty 'tui_checklist "h" "" "" "a|A" "b|B" 3<&-; echo "after rc=$?"'

    _lacks 'Device not configured'
    _has 'after rc=1'
}

@test "tui_confirm still ignores the space key" {
    run _confirm n '  y'
    [ "${status}" -eq 0 ]
}

# --- short terminals: pickers window their frame ------------------------------
# DOTS_TUI_ROWS forces the terminal height (the pickers draw at most
# rows - 1 lines per frame); the key hint line ends every frame.

# _frames_stat <file> — "<frames> <with-cursor> <max-lines>": how many frames
# were drawn, how many show a "> " cursor row, and the tallest frame in lines.
# _frames_fit <file> <max> — "<frames> <with-cursor>" must match and no frame
# may be taller than <max> lines: used as `[ "$(_frames_fit f max)" = "N N" ]`.
_frames_stat() {
    awk '
        { n++ }
        /^> / { cur = 1 }
        /↑↓\/jk move/ { f++; if (cur) c++; if (n > m) m = n; n = 0; cur = 0 }
        END { print f + 0, c + 0, m + 0 }
    ' "$1"
}

_frames_fit() {
    _ff="$(_frames_stat "$1")"
    set -- ${_ff} "$2"
    if [ "$3" -le "$4" ]; then printf '%s %s\n' "$1" "$2"; else printf 'too tall: %s > %s\n' "$3" "$4"; fi
}

# _last_frame <file> — the lines of the last frame drawn.
_last_frame() {
    awk '{ buf = buf $0 "\n" } /↑↓\/jk move/ { last = buf; buf = "" } END { printf "%s", last }' "$1"
}

@test "short terminal: a menu that fits is drawn exactly as without a height" {
    run _menu "" 'jjq'
    [ "${output}" = "quit" ]
    cp "${SANDBOX}/menu.err" "${SANDBOX}/plain.err"
    # The default menu frame is 21 lines: 22 rows (21 + the prompt line) fit.
    DOTS_TUI_ROWS=22 run _menu "" 'jjq'
    cmp "${SANDBOX}/plain.err" "${SANDBOX}/menu.err"
    DOTS_TUI_ROWS=60 run _menu "" 'jjq'
    cmp "${SANDBOX}/plain.err" "${SANDBOX}/menu.err"
    ! grep -q 'more' "${SANDBOX}/menu.err"
}

@test "short terminal: an unusable height value disables windowing" {
    run _menu "" 'q'
    cp "${SANDBOX}/menu.err" "${SANDBOX}/plain.err"
    DOTS_TUI_ROWS=abc run _menu "" 'q'
    cmp "${SANDBOX}/plain.err" "${SANDBOX}/menu.err"
    DOTS_TUI_ROWS=0 run _menu "" 'q'
    cmp "${SANDBOX}/plain.err" "${SANDBOX}/menu.err"
}

@test "short terminal: the menu windows at the top, with the hint and a down indicator" {
    DOTS_TUI_ROWS=10 run _menu "" 'q'
    [ "${output}" = "quit" ]
    [ "$(_frames_fit "${SANDBOX}/menu.err" 9)" = "1 1" ]
    grep -qx "> update     Apply dotfiles and the active theme" "${SANDBOX}/menu.err"
    grep -qx "↑↓/jk move · enter run · q quit" "${SANDBOX}/menu.err"
    grep -qx "  ↓ more" "${SANDBOX}/menu.err"
    ! grep -q "↑ more" "${SANDBOX}/menu.err"
}

@test "short terminal: the menu windows at the bottom, with the hint and an up indicator" {
    DOTS_TUI_ROWS=10 run _menu "quit" 'q'
    [ "${output}" = "quit" ]
    [ "$(_frames_fit "${SANDBOX}/menu.err" 9)" = "1 1" ]
    grep -qx "> quit       Exit" "${SANDBOX}/menu.err"
    grep -qx "↑↓/jk move · enter run · q quit" "${SANDBOX}/menu.err"
    grep -qx "  ↑ more" "${SANDBOX}/menu.err"
    ! grep -q "↓ more" "${SANDBOX}/menu.err"
}

@test "short terminal: moving down past the window scrolls it and keeps the cursor visible" {
    DOTS_TUI_ROWS=10 run _menu "" 'jjjjjjjjjjjq'
    [ "${output}" = "quit" ]
    # 1 first frame + 11 moves + the q key redraws nothing: 12 frames.
    [ "$(_frames_fit "${SANDBOX}/menu.err" 9)" = "12 12" ]
    _last_frame "${SANDBOX}/menu.err" > "${SANDBOX}/last"
    grep -qx "> quit       Exit" "${SANDBOX}/last"
    grep -qx "  ↑ more" "${SANDBOX}/last"
    ! grep -q "update " "${SANDBOX}/last"
}

@test "short terminal: moving back up scrolls the window back" {
    DOTS_TUI_ROWS=10 run _menu "quit" 'kkkkkkkkkkkq'
    [ "${output}" = "quit" ]
    [ "$(_frames_fit "${SANDBOX}/menu.err" 9)" = "12 12" ]
    _last_frame "${SANDBOX}/menu.err" > "${SANDBOX}/last"
    grep -qx "> update     Apply dotfiles and the active theme" "${SANDBOX}/last"
    grep -qx "  ↓ more" "${SANDBOX}/last"
    ! grep -q "↑ more" "${SANDBOX}/last"
}

@test "short terminal: enter in a windowed menu still runs the row under the cursor" {
    DOTS_TUI_ROWS=10 run _menu "" 'jjjjjjjjj\n'
    [ "${output}" = "uninstall" ]
}

@test "short terminal: a very short terminal drops the indicators but keeps a cursor row and the hint" {
    DOTS_TUI_ROWS=4 run _menu "" 'jjjq'
    [ "$(_frames_fit "${SANDBOX}/menu.err" 3)" = "4 4" ]
    ! grep -q "more" "${SANDBOX}/menu.err"
}

@test "short terminal: tui_choose windows its items and shows the hint" {
    DOTS_TUI_ROWS=6 run _choose "" 'jjjjjq' a b c d e f g h
    [ "$(_frames_fit "${SANDBOX}/choose.err" 5)" = "6 6" ]
    _last_frame "${SANDBOX}/choose.err" > "${SANDBOX}/last"
    grep -qx "> f" "${SANDBOX}/last"
    grep -qx "  ↑ more" "${SANDBOX}/last"
    grep -qx "  ↓ more" "${SANDBOX}/last"
    grep -qx "↑↓/jk move · enter select · q cancel" "${SANDBOX}/last"
}

@test "short terminal: tui_choose that fits is drawn exactly as without a height" {
    run _choose "" 'jq' a b c
    cp "${SANDBOX}/choose.err" "${SANDBOX}/plain.err"
    DOTS_TUI_ROWS=7 run _choose "" 'jq' a b c
    cmp "${SANDBOX}/plain.err" "${SANDBOX}/choose.err"
}

@test "short terminal: tui_checklist windows its rows and still toggles the cursor row" {
    DOTS_TUI_ROWS=6 run _checklist "" "" 'jjjj \n' 'a|A' 'b|B' 'c|C' 'd|D' 'e|E' 'f|F' 'g|G'
    [ "${output}" = "e" ]
    [ "$(_frames_fit "${SANDBOX}/checklist.err" 5)" = "6 6" ]
    _last_frame "${SANDBOX}/checklist.err" > "${SANDBOX}/last"
    grep -qx "> \[x\] E" "${SANDBOX}/last"
    grep -qx "  ↑ more" "${SANDBOX}/last"
    grep -qx "↑↓/jk move · space toggle · enter confirm · q cancel" "${SANDBOX}/last"
}

@test "short terminal: indicators are dim with color and plain without" {
    [ "$(_tui_more '↓ more' 1)" = "$(printf '  \033[2m↓ more\033[0m')" ]
    [ "$(_tui_more '↑ more' 0)" = "  ↑ more" ]
    DOTS_TUI_ROWS=10 run _menu "" 'q'
    ! grep -q $'\033' "${SANDBOX}/menu.err"
}
