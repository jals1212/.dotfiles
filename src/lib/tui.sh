#!/bin/sh
# lib/tui.sh — shared TUI presentation helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh, lib/header.sh, jq.

# shellcheck source=src/lib/log.sh
# shellcheck source=src/lib/header.sh

if ! command -v path_manifest >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "${REPO_ROOT}/src/lib/paths.sh" ]; then
        # shellcheck disable=SC1091
        . "${REPO_ROOT}/src/lib/paths.sh"
    fi
fi

if ! command -v render_header >/dev/null 2>&1; then
    if [ -n "${REPO_ROOT:-}" ] && [ -f "$(path_src_lib header.sh)" ]; then
        # shellcheck disable=SC1091
        . "$(path_src_lib header.sh)"
    fi
fi

_tui_manifest_path() {
    path_manifest
}

_tui_active_theme() {
    _tat_manifest="$(_tui_manifest_path)"
    if [ -f "${_tat_manifest}" ] && command -v jq >/dev/null 2>&1; then
        _tat_theme="$(jq -r '.theme // empty' "${_tat_manifest}" 2>/dev/null || printf '')"
        _tat_flavor="$(jq -r '.flavor // empty' "${_tat_manifest}" 2>/dev/null || printf '')"
        if [ -n "${_tat_theme}" ]; then
            if [ -n "${_tat_flavor}" ]; then
                printf '%s/%s\n' "${_tat_theme}" "${_tat_flavor}"
            else
                printf '%s\n' "${_tat_theme}"
            fi
            return 0
        fi
    fi
    printf 'kanagawa\n'
}

tui_subtitle_for() {
    case "${1:-}" in
        init) printf 'Init' ;;
        update) printf 'Update' ;;
        backup) printf 'Backup' ;;
        doctor) printf 'Doctor' ;;
        restore) printf 'Restore' ;;
        uninstall) printf 'Uninstall' ;;
        *) printf '%s' "${1:-Dotfiles Manager}" ;;
    esac
}

render_command_banner() {
    _rcb_subtitle="${1:-}"
    _rcb_theme="$(_tui_active_theme)"
    render_header "${_rcb_theme}" "${_rcb_subtitle}"
}

render_subcommand_banner() {
    [ "${DOTS_MENU_DISPATCH:-0}" = "1" ] && return 0
    render_command_banner "${1:-}"
}

tui_start_timer() {
    TUI_START_EPOCH="$(date +%s)"
    export TUI_START_EPOCH
}

tui_elapsed_seconds() {
    _tes_now="$(date +%s)"
    _tes_start="${TUI_START_EPOCH:-${_tes_now}}"
    _tes_elapsed=$((_tes_now - _tes_start))
    [ "${_tes_elapsed}" -lt 0 ] 2>/dev/null && _tes_elapsed=0
    printf '%s' "${_tes_elapsed}"
}

log_success() {
    _ls_title="${1:?log_success: title required}"
    shift || true
    tui_card "$(_header_color_code "$(_tui_active_theme)")" \
        "${_ls_title} · $(tui_elapsed_seconds)s" "$@"
}

# _tui_color_on <fd> — true when <fd> is a 256-color terminal.
_tui_color_on() {
    [ -t "${1:-1}" ] || return 1
    _tco_colors="$(tput colors 2>/dev/null || printf '8')"
    [ "${_tco_colors}" -ge 256 ] 2>/dev/null
}

# tui_card <accent> <title> [line...] — a block behind an accent bar:
#   │ <title>      (bold, accent)
#   │ <line>
# Plain text when stdout is not a 256-color terminal.
tui_card() {
    _tc_accent="${1:?tui_card: accent required}"
    _tc_title="${2:?tui_card: title required}"
    shift 2
    if _tui_color_on 1; then
        printf '\033[38;5;%sm│\033[0m \033[1;38;5;%sm%s\033[0m\n' "${_tc_accent}" "${_tc_accent}" "${_tc_title}"
        for _tc_line in "$@"; do
            printf '\033[38;5;%sm│\033[0m %s\n' "${_tc_accent}" "${_tc_line}"
        done
    else
        printf '│ %s\n' "${_tc_title}"
        for _tc_line in "$@"; do
            printf '│ %s\n' "${_tc_line}"
        done
    fi
}

# ---------------------------------------------------------------------------
# Main menu rows "<group>|<value>|<description>", in display order. A row whose
# group differs from the previous row's starts a group header.
# ---------------------------------------------------------------------------
_TUI_MENU_ROWS='Maintain|update|Apply dotfiles and the active theme
Maintain|upgrade|Bump vendored deps plus brew and mise
Maintain|clean|Remove dead symlinks and stale backups
Maintain|doctor|Health checks that change nothing
Appearance|theme|Switch theme or flavor
Appearance|prompt|Switch prompt engine: starship or p10k
Danger|uninstall|⚠ Remove managed symlinks and manifest
General|help|Show usage
General|quit|Exit'

_tui_menu_count() {
    printf '%s\n' "${_TUI_MENU_ROWS}" | wc -l | tr -d ' '
}

# _tui_menu_value <n> — value of the 1-based row <n>.
_tui_menu_value() {
    printf '%s\n' "${_TUI_MENU_ROWS}" | sed -n "${1}p" | cut -d'|' -f2
}

# _tui_menu_index <value> — 1-based row of <value>; empty when unknown.
_tui_menu_index() {
    printf '%s\n' "${_TUI_MENU_ROWS}" | awk -F'|' -v v="${1:-}" '$2 == v { print NR; exit }'
}

# _tui_menu_frame <cursor> <accent> <color 0|1> — the menu as text lines.
_tui_menu_frame() {
    printf '%s\n' "${_TUI_MENU_ROWS}" | awk -F'|' -v cur="$1" -v acc="$2" -v color="$3" '
        function paint(code, text) { return color ? "\033[" code "m" text "\033[0m" : text }
        {
            if ($1 != prev) {
                if (NR > 1) print ""
                print paint("2", $1)
                prev = $1
            }
            name = sprintf("%-10s", $2)
            if (NR == cur)
                print paint("1;38;5;" acc, "> " name) " " $3
            else
                print "  " name " " paint("2", $3)
        }
        END { print ""; print paint("2", "↑↓/jk move · enter run · q quit") }
    '
}

# _tui_read_key — read one key from fd 3: up, down, enter, quit or other.
# End of input and a lone esc count as quit.
_tui_read_key() {
    _trk_c="$(dd bs=1 count=1 2>/dev/null <&3; printf x)"
    _trk_c="${_trk_c%x}"
    case "${_trk_c}" in
        '') printf 'quit' ;;
        # Literal newline: "$(printf '\n')" would be empty (stripped).
        '
'|"$(printf '\r')") printf 'enter' ;;
        q|Q) printf 'quit' ;;
        y|Y) printf 'yes' ;;
        n|N) printf 'no' ;;
        k) printf 'up' ;;
        j) printf 'down' ;;
        "$(printf '\033')")
            # Arrow keys arrive as esc [ A|B (or esc O A|B). On a tty, wait at
            # most 0.1s for the rest so a lone esc still quits.
            [ -t 3 ] && stty min 0 time 1 <&3
            _trk_s="$(dd bs=1 count=2 2>/dev/null <&3)"
            [ -t 3 ] && stty min 1 time 0 <&3
            case "${_trk_s}" in
                '[A'|OA) printf 'up' ;;
                '[B'|OB) printf 'down' ;;
                '') printf 'quit' ;;
                *) printf 'other' ;;
            esac
            ;;
        *) printf 'other' ;;
    esac
}

# _tui_open_keys — make sure fd 3 (where keys are read) is open; the caller
# may have opened it (the ./dots menu loop, tests), otherwise use /dev/tty.
# Without a controlling terminal `exec 3</dev/tty` aborts a POSIX sh, so probe
# in a subshell first and fail closed: fd 3 on /dev/null reads as end of input,
# which every caller treats as cancel.
_tui_open_keys() {
    { true <&3; } 2>/dev/null && return 0
    if ( : </dev/tty ) 2>/dev/null; then
        exec 3</dev/tty
    else
        exec 3</dev/null
    fi
}

# _tui_traps_save — remember the caller's traps in _TUI_OLD_TRAPS.
# `$(trap)` is not enough: macOS /bin/sh (bash) reports the parent's traps in a
# command substitution, but dash resets them there and prints nothing. So write
# `trap` to a file from the current shell and read that back.
_tui_traps_save() {
    _TUI_OLD_TRAPS=""
    _tts_file="$(mktemp "${TMPDIR:-/tmp}/dots-traps.XXXXXX" 2>/dev/null)" || _tts_file=""
    if [ -n "${_tts_file}" ]; then
        trap >"${_tts_file}" 2>/dev/null
        _TUI_OLD_TRAPS="$(cat "${_tts_file}")"
        rm -f "${_tts_file}"
    else
        _TUI_OLD_TRAPS="$(trap)"
    fi
}

# _tui_traps_restore — drop our INT/TERM trap and put the caller's back.
# Only INT and TERM are replayed (each saved entry is "trap -- <body> <SIG>"),
# so an EXIT trap is never re-armed inside a subshell.
_tui_traps_restore() {
    trap - INT TERM
    [ -n "${_TUI_OLD_TRAPS:-}" ] || return 0
    # shellcheck disable=SC2329  # invoked through the eval below
    _tui_replay_trap() {
        case "$3" in
            INT|SIGINT|TERM|SIGTERM) trap -- "$2" "$3" ;;
        esac
    }
    # Rewrite only the "trap -- " that starts a statement: a line inside a
    # quoted multi-line trap body may also begin with "trap -- " and must stay
    # verbatim. Track single quotes (and backslash escapes outside them).
    eval "$(printf '%s\n' "${_TUI_OLD_TRAPS}" | awk '
        {
            line = $0
            if (!inq && substr(line, 1, 8) == "trap -- ")
                line = "_tui_replay_trap -- " substr(line, 9)
            n = length($0); esc = 0
            for (i = 1; i <= n; i++) {
                c = substr($0, i, 1)
                if (inq) { if (c == "\047") inq = 0 }
                else if (esc) esc = 0
                else if (c == "\\") esc = 1
                else if (c == "\047") inq = 1
            }
            print line
        }')"
}

# _tui_pick <frame-fn> <count> <cursor> — key loop shared by every picker.
# Draws "<frame-fn> <cursor> <accent> <color>" on stderr after each key and
# prints the chosen 1-based index, or 0 for q, esc or end of input. Needs
# _TUI_PICK_ACCENT set by the caller.
_tui_pick() {
    _tp_frame_fn="$1"
    _tp_n="$2"
    _tp_cur="$3"
    _tui_open_keys
    _tp_color=0
    _tui_color_on 2 && _tp_color=1

    _tp_stty=""
    _tp_restore() {
        [ -n "${_tp_stty}" ] && stty "${_tp_stty}" <&3
        [ -t 2 ] && printf '\033[?25h' >&2
        return 0
    }
    _tui_traps_save
    trap '_tp_restore; exit 130' INT TERM
    if [ -t 3 ]; then
        _tp_stty="$(stty -g <&3)"
        stty -icanon -echo min 1 time 0 <&3
    fi
    [ -t 2 ] && printf '\033[?25l' >&2

    _tp_lines=0
    while :; do
        _tp_frame="$("${_tp_frame_fn}" "${_tp_cur}" "${_TUI_PICK_ACCENT:-141}" "${_tp_color}")"
        if [ -t 2 ]; then
            [ "${_tp_lines}" -gt 0 ] && printf '\033[%dA' "${_tp_lines}" >&2
            printf '%s\n' "${_tp_frame}" | awk '{ printf "\033[2K%s\n", $0 }' >&2
        else
            printf '%s\n' "${_tp_frame}" >&2
        fi
        _tp_lines="$(printf '%s\n' "${_tp_frame}" | wc -l | tr -d ' ')"
        case "$(_tui_read_key)" in
            up) [ "${_tp_cur}" -gt 1 ] && _tp_cur=$((_tp_cur - 1)) ;;
            down) [ "${_tp_cur}" -lt "${_tp_n}" ] && _tp_cur=$((_tp_cur + 1)) ;;
            enter) _tp_pick="${_tp_cur}"; break ;;
            quit) _tp_pick=0; break ;;
        esac
    done
    _tp_restore
    _tui_traps_restore
    printf '%s\n' "${_tp_pick}"
}

# render_action_menu [last] — the ./dots action picker. Draws on stderr, reads
# keys from fd 3 and prints the chosen value on stdout: "quit" for q, esc or
# end of input. [last] (a value) starts under the cursor.
render_action_menu() {
    _ram_cur="$(_tui_menu_index "${1:-}")"
    [ -n "${_ram_cur}" ] || _ram_cur=1
    _TUI_PICK_ACCENT="$(_header_color_code "$(_tui_active_theme)")"
    _ram_idx="$(_tui_pick _tui_menu_frame "$(_tui_menu_count)" "${_ram_cur}")"
    if [ "${_ram_idx:-0}" -eq 0 ]; then
        printf 'quit\n'
    else
        _tui_menu_value "${_ram_idx}"
    fi
}

# tui_confirm <question> <default y|n> — one-key yes/no on fd 3.
# Returns 0 for y, 1 for n, the default for enter, and 130 for q, esc or end
# of input. Other keys are ignored. Draws "<question> [y/N] <answer>" on stderr.
tui_confirm() {
    _tcf_q="${1:?tui_confirm: question required}"
    _tcf_default="${2:?tui_confirm: default y|n required}"
    case "${_tcf_default}" in
        y) _tcf_hint='[Y/n]' ;;
        n) _tcf_hint='[y/N]' ;;
        *) log_error "tui_confirm: default must be y or n"; return 2 ;;
    esac
    _tui_open_keys
    if _tui_color_on 2; then
        printf '\033[1m%s\033[0m \033[2m%s\033[0m ' "${_tcf_q}" "${_tcf_hint}" >&2
    else
        printf '%s %s ' "${_tcf_q}" "${_tcf_hint}" >&2
    fi
    _tcf_stty=""
    _tui_traps_save
    trap '[ -n "${_tcf_stty}" ] && stty "${_tcf_stty}" <&3; exit 130' INT TERM
    if [ -t 3 ]; then
        _tcf_stty="$(stty -g <&3)"
        stty -icanon -echo min 1 time 0 <&3
    fi
    while :; do
        case "$(_tui_read_key)" in
            yes) _tcf_ans=y; break ;;
            no) _tcf_ans=n; break ;;
            enter) _tcf_ans="${_tcf_default}"; break ;;
            quit) _tcf_ans=""; break ;;
        esac
    done
    [ -n "${_tcf_stty}" ] && stty "${_tcf_stty}" <&3
    _tui_traps_restore
    printf '%s\n' "${_tcf_ans}" >&2
    case "${_tcf_ans}" in
        y) return 0 ;;
        n) return 1 ;;
        *) return 130 ;;
    esac
}

# _tui_choose_frame <cursor> <accent> <color> — frame for tui_choose, from
# _TUI_CHOOSE_HEADER and the newline-separated _TUI_CHOOSE_ITEMS.
_tui_choose_frame() {
    printf '%s\n' "${_TUI_CHOOSE_ITEMS}" | awk -v cur="$1" -v acc="$2" -v color="$3" -v hdr="${_TUI_CHOOSE_HEADER}" '
        function paint(code, text) { return color ? "\033[" code "m" text "\033[0m" : text }
        NR == 1 { print paint("1;38;5;" acc, hdr) }
        { print (NR == cur) ? paint("1;38;5;" acc, "> " $0) : "  " $0 }
        END { print ""; print paint("2", "↑↓/jk move · enter select · q cancel") }
    '
}

# tui_choose <header> <current> <item...> — pick one item. Prints it and
# returns 0; prints nothing and returns 1 on q, esc or end of input.
# <current> (an item, or empty) starts under the cursor.
tui_choose() {
    _TUI_CHOOSE_HEADER="${1:?tui_choose: header required}"
    _tch_current="${2:-}"
    shift 2
    _TUI_CHOOSE_ITEMS="$(printf '%s\n' "$@")"
    _tch_cur="$(printf '%s\n' "${_TUI_CHOOSE_ITEMS}" | awk -v v="${_tch_current}" '$0 == v { print NR; exit }')"
    [ -n "${_tch_cur}" ] || _tch_cur=1
    _TUI_PICK_ACCENT="${_TUI_PICK_ACCENT:-$(_header_color_code "$(_tui_active_theme)")}"
    _tch_idx="$(_tui_pick _tui_choose_frame "$#" "${_tch_cur}")"
    [ "${_tch_idx:-0}" -gt 0 ] || return 1
    printf '%s\n' "${_TUI_CHOOSE_ITEMS}" | sed -n "${_tch_idx}p"
}

# _tui_git_summary — "✓ clean", "N changed", "N unpushed" or both; empty when
# REPO_ROOT is not a git work tree. Local only: never fetches.
_tui_git_summary() {
    _tgs_root="${REPO_ROOT:-.}"
    git -C "${_tgs_root}" rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    _tgs_changed="$(git -C "${_tgs_root}" status --porcelain 2>/dev/null | wc -l | tr -d ' ')"
    _tgs_ahead="$(git -C "${_tgs_root}" rev-list --count '@{u}..HEAD' 2>/dev/null || printf '0')"
    if [ "${_tgs_changed}" -eq 0 ] && [ "${_tgs_ahead}" -eq 0 ]; then
        printf '✓ clean'
        return 0
    fi
    _tgs_out=""
    [ "${_tgs_changed}" -gt 0 ] && _tgs_out="${_tgs_changed} changed"
    if [ "${_tgs_ahead}" -gt 0 ]; then
        [ -n "${_tgs_out}" ] && _tgs_out="${_tgs_out}, "
        _tgs_out="${_tgs_out}${_tgs_ahead} unpushed"
    fi
    printf '%s' "${_tgs_out}"
}

# render_menu_status — one-line menu header:
#   jals1212 DOTS · <theme[/flavor]> · <prompt> · <git summary>
# Prompt and git parts are omitted when unknown. Brand in the theme accent and
# the rest dimmed when stdout is a 256-color tty; plain text otherwise.
render_menu_status() {
    _rms_theme="$(_tui_active_theme)"
    _rms_prompt=""
    _rms_manifest="$(_tui_manifest_path)"
    if [ -f "${_rms_manifest}" ] && command -v jq >/dev/null 2>&1; then
        _rms_prompt="$(jq -r '.prompt // empty' "${_rms_manifest}" 2>/dev/null || printf '')"
    fi
    _rms_rest="${_rms_theme}"
    [ -n "${_rms_prompt}" ] && _rms_rest="${_rms_rest} · ${_rms_prompt}"
    _rms_git="$(_tui_git_summary)"
    [ -n "${_rms_git}" ] && _rms_rest="${_rms_rest} · ${_rms_git}"

    if _tui_color_on 1; then
        printf '\033[1;38;5;%sm%s\033[0m \033[2m· %s\033[0m\n' \
            "$(_header_color_code "${_rms_theme}")" "jals1212 DOTS" "${_rms_rest}"
    else
        printf 'jals1212 DOTS · %s\n' "${_rms_rest}"
    fi
}
