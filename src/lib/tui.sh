#!/bin/sh
# lib/tui.sh — shared TUI presentation helpers
# POSIX sh. Source this file; do not execute directly.
# Requires: lib/log.sh, lib/header.sh, jq, gum (log_success only).

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

    _ls_accent="$(_header_color_code "$(_tui_active_theme)")"
    _ls_elapsed="$(tui_elapsed_seconds)"
    _ls_text="${_ls_title} · ${_ls_elapsed}s"

    for _ls_line in "$@"; do
        _ls_text="${_ls_text}
${_ls_line}"
    done

    gum style \
        --border rounded \
        --border-foreground "${_ls_accent}" \
        --padding "1 2" \
        --bold \
        "${_ls_text}"
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

# render_action_menu [last] — interactive action picker. Draws on stderr,
# reads keys from fd 3 (opened on /dev/tty when the caller did not open it)
# and prints the chosen value on stdout: "quit" for q, esc or end of input.
# [last] (a value) starts under the cursor.
render_action_menu() {
    { true <&3; } 2>/dev/null || exec 3</dev/tty
    _ram_cur="$(_tui_menu_index "${1:-}")"
    [ -n "${_ram_cur}" ] || _ram_cur=1
    _ram_n="$(_tui_menu_count)"
    _ram_accent="$(_header_color_code "$(_tui_active_theme)")"
    _ram_color=0
    if [ -t 2 ]; then
        _ram_colors="$(tput colors 2>/dev/null || printf '8')"
        [ "${_ram_colors}" -ge 256 ] 2>/dev/null && _ram_color=1
    fi

    _ram_stty=""
    if [ -t 3 ]; then
        _ram_stty="$(stty -g <&3)"
        stty -icanon -echo min 1 time 0 <&3
    fi
    _ram_restore() {
        [ -n "${_ram_stty}" ] && stty "${_ram_stty}" <&3
        [ -t 2 ] && printf '\033[?25h' >&2
        return 0
    }
    trap '_ram_restore; exit 130' INT TERM
    [ -t 2 ] && printf '\033[?25l' >&2

    _ram_lines=0
    while :; do
        _ram_frame="$(_tui_menu_frame "${_ram_cur}" "${_ram_accent}" "${_ram_color}")"
        if [ -t 2 ]; then
            [ "${_ram_lines}" -gt 0 ] && printf '\033[%dA' "${_ram_lines}" >&2
            printf '%s\n' "${_ram_frame}" | awk '{ printf "\033[2K%s\n", $0 }' >&2
        else
            printf '%s\n' "${_ram_frame}" >&2
        fi
        _ram_lines="$(printf '%s\n' "${_ram_frame}" | wc -l | tr -d ' ')"
        case "$(_tui_read_key)" in
            up) [ "${_ram_cur}" -gt 1 ] && _ram_cur=$((_ram_cur - 1)) ;;
            down) [ "${_ram_cur}" -lt "${_ram_n}" ] && _ram_cur=$((_ram_cur + 1)) ;;
            enter) _ram_pick="$(_tui_menu_value "${_ram_cur}")"; break ;;
            quit) _ram_pick="quit"; break ;;
        esac
    done
    _ram_restore
    trap - INT TERM
    printf '%s\n' "${_ram_pick}"
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

    _rms_colors=0
    [ -t 1 ] && _rms_colors="$(tput colors 2>/dev/null || printf '8')"
    if [ "${_rms_colors}" -ge 256 ] 2>/dev/null; then
        printf '\033[1;38;5;%sm%s\033[0m \033[2m· %s\033[0m\n' \
            "$(_header_color_code "${_rms_theme}")" "jals1212 DOTS" "${_rms_rest}"
    else
        printf 'jals1212 DOTS · %s\n' "${_rms_rest}"
    fi
}
